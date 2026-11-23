class Document < ApplicationRecord
  KINDS = %w[ estimate delivery invoice receipt ].freeze
  KIND_LABELS = {
    "estimate" => "見積書",
    "delivery" => "納品書",
    "invoice" => "請求書",
    "receipt" => "領収書"
  }.freeze
  STATUS_LABELS = { "draft" => "下書き", "issued" => "発行済み" }.freeze
  PAYMENT_STATUS_LABELS = { "unpaid" => "未入金", "partial" => "一部入金", "paid" => "入金済み" }.freeze
  # 変換できる組み合わせ（変換元の種別 => 変換先の種別）
  CONVERSIONS = {
    "estimate" => %w[ delivery invoice ],
    "delivery" => %w[ invoice ],
    "invoice" => %w[ receipt ],
    "receipt" => %w[]
  }.freeze

  enum :kind, { estimate: "estimate", delivery: "delivery", invoice: "invoice", receipt: "receipt" }, validate: true
  enum :status, { draft: "draft", issued: "issued" }, validate: true
  # 入金ステータスは請求書だけが持つ（他の種別は NULL のため、
  # enum の validate は使わず allow_nil 付きで自前検証する）
  enum :payment_status, { unpaid: "unpaid", partial: "partial", paid: "paid" }, prefix: :payment

  belongs_to :tenant
  belongs_to :client
  belongs_to :converted_from, class_name: "Document", optional: true
  has_many :conversions, class_name: "Document", foreign_key: :converted_from_id,
           dependent: :nullify, inverse_of: :converted_from
  has_many :document_lines, -> { order(:position, :id) },
           dependent: :destroy, inverse_of: :document
  has_many :document_deliveries, -> { order(sent_at: :desc, id: :desc) },
           dependent: :destroy, inverse_of: :document
  has_many :payments, -> { order(paid_on: :asc, id: :asc) },
           dependent: :destroy, inverse_of: :document
  # この帳票をテンプレートにする定期請求。使われている間は削除できない
  has_many :recurring_schedules, class_name: "RecurringDocument", foreign_key: :template_document_id,
           dependent: :restrict_with_error, inverse_of: :template_document

  accepts_nested_attributes_for :document_lines, allow_destroy: true,
    reject_if: ->(attrs) { attrs["name"].blank? && attrs["quantity"].blank? && attrs["unit_price"].blank? }

  validates :payment_status, inclusion: { in: PAYMENT_STATUS_LABELS.keys }, allow_nil: true
  validates :issue_date, presence: true
  validates :number, presence: true, uniqueness: { scope: %i[ tenant_id kind ] }
  validate :must_have_lines
  validate :client_must_belong_to_tenant
  validate :converted_from_must_belong_to_tenant
  validate :invoice_monthly_limit_not_exceeded, on: :create

  before_validation :set_default_issue_date
  before_validation :set_default_payment_status
  # 帳票番号は作成時に採番する（発行時ではない）。一度振った番号は、
  # 発行日や種別を後から変えても振り直さない。
  before_validation :assign_number, on: :create
  before_save :assign_line_positions

  def kind_label
    KIND_LABELS[kind]
  end

  def status_label
    STATUS_LABELS[status]
  end

  def payment_status_label
    PAYMENT_STATUS_LABELS[payment_status]
  end

  # 入金済み金額（入金レコードの合計）
  def received_amount
    payments.sum(&:amount)
  end

  # 未入金残高（過入金の場合はマイナスになる）
  def balance
    total - received_amount
  end

  # 支払期限を過ぎても未入金・一部入金の請求書かどうか
  def overdue?(today = Date.current)
    invoice? && issued? && due_date.present? && due_date < today &&
      (payment_unpaid? || payment_partial?)
  end

  # 発行済みで未入金・一部入金の請求書（未入金一覧用）。支払期限の早い順
  scope :unpaid_invoices, -> {
    invoice.issued.where(payment_status: %w[ unpaid partial ]).order(due_date: :asc, id: :asc)
  }

  # 入金合計から入金ステータスを再計算して保存する。入金の登録・変更・
  # 削除時と、合計金額が変わったときに呼ぶ。請求書以外では何もしない。
  def recalculate_payment_status!
    return self unless invoice?

    received = payments.sum(:amount)
    new_status =
      if received <= 0
        "unpaid"
      elsif received < total
        "partial"
      else
        "paid"
      end
    update!(payment_status: new_status) if payment_status != new_status
    self
  end

  def convertible_kinds
    CONVERSIONS.fetch(kind)
  end

  # 明細から合計を再計算して保存する。明細の保存後に呼ぶこと
  # （コントローラの create / update / convert から呼ぶ）。
  def recalculate_totals!
    result = DocumentTaxCalculator.new(tenant: tenant, lines: document_lines.to_a).call
    update!(subtotal: result.subtotal, tax_amount: result.tax_amount,
            total: result.total, tax_breakdown: result.breakdown)
    recalculate_payment_status!
    self
  end

  # 公開リンク（リンク共有）用。署名付きIDで、ログインなしに印刷画面を
  # 見られる。目的（purpose）を分け、有効期限を過ぎたものは無効になる。
  PUBLIC_LINK_PURPOSE = "public_view"
  PUBLIC_LINK_TTL = 30.days

  def public_link_token
    signed_id(purpose: PUBLIC_LINK_PURPOSE, expires_in: PUBLIC_LINK_TTL)
  end

  # 署名が不正・期限切れの場合は nil を返す
  def self.find_by_public_link_token(token)
    find_signed(token, purpose: PUBLIC_LINK_PURPOSE)
  end

  # メールで送信する。下書きなら発行済みにし、送信履歴を残す。
  def deliver_by_email!(recipient_email)
    raise ArgumentError, "送信先メールアドレスがありません" if recipient_email.blank?

    token = public_link_token
    DocumentMailer.document_email(document: self, recipient_email: recipient_email, token: token).deliver_now
    update!(status: :issued) if draft?
    document_deliveries.create!(
      tenant: tenant, channel: "email", recipient_email: recipient_email,
      sent_at: Time.current, token_digest: Digest::SHA256.hexdigest(token)
    )
  end

  # 別の種別へ変換した新しい帳票を作る。変換元は変更しない。
  # 取引先・件名・備考・明細を引き継ぎ、発行日は変換日、番号は新規採番になる。
  def convert_to(target_kind)
    target_kind = target_kind.to_s
    unless convertible_kinds.include?(target_kind)
      raise ArgumentError, "#{kind_label}から#{KIND_LABELS[target_kind] || target_kind}へは変換できません"
    end

    converted = tenant.documents.build(
      kind: target_kind,
      client: client,
      title: title,
      notes: notes,
      issue_date: Date.current,
      status: :draft,
      converted_from: self
    )
    document_lines.each do |line|
      converted.document_lines.build(
        item: line.item, name: line.name, quantity: line.quantity, unit: line.unit,
        unit_price: line.unit_price, tax_rate: line.tax_rate, position: line.position
      )
    end
    converted.save!
    converted.recalculate_totals!
    converted
  end

  # 同じ種別のまま複写した新しい帳票（下書き）を作る。元は変更しない。
  # 取引先・件名・備考・明細を引き継ぎ、発行日は今日、番号は新規採番。
  # 支払期限は「発行日からの日数」を引き継ぐ。入金・送信履歴は引き継がない。
  def duplicate!
    new_due_date = (Date.current + (due_date - issue_date)) if due_date && issue_date
    copy = tenant.documents.build(
      kind: kind,
      client: client,
      title: title,
      notes: notes,
      issue_date: Date.current,
      due_date: new_due_date,
      status: :draft
    )
    document_lines.each do |line|
      copy.document_lines.build(
        item: line.item, name: line.name, quantity: line.quantity, unit: line.unit,
        unit_price: line.unit_price, tax_rate: line.tax_rate, position: line.position
      )
    end
    copy.save!
    copy.recalculate_totals!
    copy
  end

  private
    def set_default_issue_date
      self.issue_date ||= Date.current
    end

    def set_default_payment_status
      self.payment_status ||= "unpaid" if invoice?
    end

    def assign_number
      return if number.present?
      return if tenant.blank? || kind.blank? || issue_date.blank?

      sequence = DocumentSequence.next_value(tenant: tenant, kind: kind, issue_date: issue_date)
      self.number = "#{tenant.document_number_prefix}#{issue_date.strftime('%Y%m')}-#{format('%03d', sequence)}"
    end

    def assign_line_positions
      document_lines.each_with_index { |line, index| line.position = index }
    end

    # 請求書はテナントの月間上限（発行日の属する月）までしか作れない。
    # 上限が NULL のテナントは無制限。
    def invoice_monthly_limit_not_exceeded
      return unless invoice?
      return if tenant.blank? || issue_date.blank?
      return unless tenant.invoice_limit_reached?(issue_date)

      errors.add(:base, "今月の請求書の発行上限（#{tenant.monthly_invoice_limit}通）に達しました。これ以上は作成できません。")
    end

    def must_have_lines
      return if document_lines.reject(&:marked_for_destruction?).any?

      errors.add(:document_lines, "を1行以上入力してください")
    end

    def client_must_belong_to_tenant
      return if client.blank? || tenant.blank?
      return if client.tenant_id == tenant_id

      errors.add(:client, "は自社の取引先ではありません")
    end

    def converted_from_must_belong_to_tenant
      return if converted_from.blank? || tenant.blank?
      return if converted_from.tenant_id == tenant_id

      errors.add(:converted_from, "は自社の帳票ではありません")
    end
end

class Document < ApplicationRecord
  KINDS = %w[ estimate delivery invoice receipt ].freeze
  KIND_LABELS = {
    "estimate" => "見積書",
    "delivery" => "納品書",
    "invoice" => "請求書",
    "receipt" => "領収書"
  }.freeze
  STATUS_LABELS = { "draft" => "下書き", "issued" => "発行済み" }.freeze
  # 変換できる組み合わせ（変換元の種別 => 変換先の種別）
  CONVERSIONS = {
    "estimate" => %w[ delivery invoice ],
    "delivery" => %w[ invoice ],
    "invoice" => %w[ receipt ],
    "receipt" => %w[]
  }.freeze

  enum :kind, { estimate: "estimate", delivery: "delivery", invoice: "invoice", receipt: "receipt" }, validate: true
  enum :status, { draft: "draft", issued: "issued" }, validate: true

  belongs_to :tenant
  belongs_to :client
  belongs_to :converted_from, class_name: "Document", optional: true
  has_many :conversions, class_name: "Document", foreign_key: :converted_from_id,
           dependent: :nullify, inverse_of: :converted_from
  has_many :document_lines, -> { order(:position, :id) },
           dependent: :destroy, inverse_of: :document

  accepts_nested_attributes_for :document_lines, allow_destroy: true,
    reject_if: ->(attrs) { attrs["name"].blank? && attrs["quantity"].blank? && attrs["unit_price"].blank? }

  validates :issue_date, presence: true
  validates :number, presence: true, uniqueness: { scope: %i[ tenant_id kind ] }
  validate :must_have_lines
  validate :client_must_belong_to_tenant
  validate :converted_from_must_belong_to_tenant

  before_validation :set_default_issue_date
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

  def convertible_kinds
    CONVERSIONS.fetch(kind)
  end

  # 明細から合計を再計算して保存する。明細の保存後に呼ぶこと
  # （コントローラの create / update / convert から呼ぶ）。
  def recalculate_totals!
    result = DocumentTaxCalculator.new(tenant: tenant, lines: document_lines.to_a).call
    update!(subtotal: result.subtotal, tax_amount: result.tax_amount,
            total: result.total, tax_breakdown: result.breakdown)
    self
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

  private
    def set_default_issue_date
      self.issue_date ||= Date.current
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

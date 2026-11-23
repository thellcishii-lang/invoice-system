# 定期請求のスケジュール。テンプレート帳票（請求書）の明細をコピーして、
# 毎月 day_of_month の日に新しい請求書を自動作成する。
class RecurringDocument < ApplicationRecord
  belongs_to :tenant
  belongs_to :client
  belongs_to :template_document, class_name: "Document"
  belongs_to :send_template, optional: true

  scope :active, -> { where(active: true) }
  scope :due, ->(date) { active.where(next_run_date: ..date) }

  # 月末日のブレを避けるため、実行日は 1〜28 日に限る
  validates :day_of_month, numericality: { only_integer: true, in: 1..28 }
  validate :client_must_belong_to_tenant
  validate :template_must_be_own_invoice

  before_validation :set_initial_next_run_date, on: :create
  before_save :reschedule_if_day_changed

  # from 以降で最初に来る実行日（day_of_month の日）
  def next_occurrence(from)
    candidate = Date.new(from.year, from.month, day_of_month)
    candidate >= from ? candidate : candidate.next_month
  end

  # 実行：テンプレートから新しい請求書を作る。
  #
  # 支払期限の決め方：テンプレートの「発行日→支払期限」の月数差と支払日を
  # そのまま引き継ぐ（例：発行 10/10・期限 11/30 のテンプレートからは、
  # 翌月末日が期限になる）。支払日がその月に無い場合は月末に丸める。
  # テンプレートに支払期限が無ければ、発行月の月末とする。
  def generate_document!(today)
    template = template_document
    document = tenant.documents.build(
      kind: "invoice",
      client: client,
      title: template.title,
      notes: template.notes,
      issue_date: today,
      due_date: derive_due_date(today),
      status: :draft
    )
    template.document_lines.each do |line|
      document.document_lines.build(
        item: line.item, name: line.name, quantity: line.quantity, unit: line.unit,
        unit_price: line.unit_price, cost_unit_price: line.cost_unit_price, tax_rate: line.tax_rate, position: line.position
      )
    end
    document.save!
    document.recalculate_totals!
    document
  end

  SEND_METHODS = %w[ none email fax ].freeze
  SEND_METHOD_LABELS = { "none" => "指定しない（手動で印刷して送る）", "email" => "メールで送信", "fax" => "FAXで送信" }.freeze

  validates :send_method, inclusion: { in: SEND_METHODS }

  def send_method_label
    SEND_METHOD_LABELS[send_method]
  end

  # 実行してスケジュールを進める。送信方法が決まっていれば、作成した請求書を
  # その方法で送信する。送れなかった場合は送信履歴に「送信不可」で残り、
  # 後から手動で再送できる。
  def run!(today)
    document = generate_document!(today)
    case send_method
    when "email"
      if client.email.present?
        document.attempt_delivery!(channel: "email", recipient: client.email,
                                   send_template: matching_send_template)
      else
        document.record_failed_delivery!(channel: "email", error_message: "取引先にメールアドレスが登録されていません")
      end
    when "fax"
      if client.fax_number.present?
        document.attempt_delivery!(channel: "fax", recipient: client.fax_number)
      else
        document.record_failed_delivery!(channel: "fax", error_message: "取引先にFAX番号が登録されていません")
      end
    end
    update!(last_run_date: today, next_run_date: next_occurrence(today + 1.day))
    document
  end

  private
    # 送り状テンプレートは、送信方法とチャネルが一致する場合だけ使う
    def matching_send_template
      send_template if send_template && send_template.channel == send_method
    end

    def derive_due_date(issue_date)
      template = template_document
      return issue_date.end_of_month if template.due_date.blank?

      months = (template.due_date.year * 12 + template.due_date.month) -
               (template.issue_date.year * 12 + template.issue_date.month)
      target = issue_date.next_month(months)
      day = [ template.due_date.day, target.end_of_month.day ].min
      Date.new(target.year, target.month, day)
    end

    def set_initial_next_run_date
      return unless day_of_month.is_a?(Integer) && (1..28).cover?(day_of_month)

      self.next_run_date ||= next_occurrence(Date.current)
    end

    def reschedule_if_day_changed
      return unless persisted? && day_of_month_changed?

      self.next_run_date = next_occurrence(Date.current)
    end

    def client_must_belong_to_tenant
      return if client.blank? || tenant.blank?
      return if client.tenant_id == tenant_id

      errors.add(:client, "は自社の取引先ではありません")
    end

    def template_must_be_own_invoice
      return if template_document.blank? || tenant.blank?
      return errors.add(:template_document, "は自社の帳票ではありません") if template_document.tenant_id != tenant_id
      return errors.add(:template_document, "は請求書ではありません") unless template_document.invoice?
      return if template_document.client_id == client_id

      errors.add(:template_document, "の取引先が一致しません")
    end
end

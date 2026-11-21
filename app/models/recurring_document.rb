# 定期請求のスケジュール。テンプレート帳票（請求書）の明細をコピーして、
# 毎月 day_of_month の日に新しい請求書を自動作成する。
class RecurringDocument < ApplicationRecord
  belongs_to :tenant
  belongs_to :client
  belongs_to :template_document, class_name: "Document"

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
        unit_price: line.unit_price, tax_rate: line.tax_rate, position: line.position
      )
    end
    document.save!
    document.recalculate_totals!
    document
  end

  # 実行してスケジュールを進める。auto_send が有効で取引先にメールアドレスが
  # あれば、作成した請求書をそのまま送信する（発行済みになり送信履歴が残る）。
  def run!(today)
    document = generate_document!(today)
    document.deliver_by_email!(client.email) if auto_send && client.email.present?
    update!(last_run_date: today, next_run_date: next_occurrence(today + 1.day))
    document
  end

  private
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

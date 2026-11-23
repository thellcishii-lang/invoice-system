class DocumentTemplate < ApplicationRecord
  belongs_to :tenant
  has_many :document_template_lines, -> { order(:position, :id) },
           dependent: :destroy, inverse_of: :document_template
  accepts_nested_attributes_for :document_template_lines, allow_destroy: true,
                                reject_if: ->(attrs) { attrs[:name].blank? && attrs[:item_id].blank? }

  validates :name, presence: true
  validates :kind, inclusion: { in: Document::KINDS }

  def kind_label
    Document::KIND_LABELS[kind]
  end

  # 明細の合計（税込表示の場合は税込、それ以外は税抜の明細金額の合計）
  def lines_total
    document_template_lines.sum(&:amount)
  end

  # テンプレートから新規帳票（下書き）を組み立てる。取引先は作成画面で選ぶ。
  def build_document
    document = tenant.documents.build(
      kind: kind, title: title, notes: notes,
      issue_date: Date.current, status: :draft
    )
    document.due_date = Date.current + 30.days if kind == "estimate"
    document_template_lines.each do |line|
      document.document_lines.build(
        item: line.item, name: line.name, quantity: line.quantity, unit: line.unit,
        unit_price: line.unit_price, cost_unit_price: line.cost_unit_price, tax_rate: line.tax_rate, position: line.position
      )
    end
    document
  end

  # 既存の帳票からテンプレートを組み立てる（「テンプレートとして保存」用）
  def self.from_document(document)
    template = document.tenant.document_templates.build(
      kind: document.kind_value,
      name: document.title.presence || "#{document.kind_label}テンプレート",
      title: document.title,
      notes: document.notes
    )
    document.document_lines.each do |line|
      template.document_template_lines.build(
        item: line.item, name: line.name, quantity: line.quantity, unit: line.unit,
        unit_price: line.unit_price, cost_unit_price: line.cost_unit_price, tax_rate: line.tax_rate, position: line.position
      )
    end
    template
  end
end

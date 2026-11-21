class Payment < ApplicationRecord
  METHODS = %w[ bank_transfer cash card other ].freeze
  METHOD_LABELS = {
    "bank_transfer" => "振込",
    "cash" => "現金",
    "card" => "カード",
    "other" => "その他"
  }.freeze

  enum :method, { bank_transfer: "bank_transfer", cash: "cash", card: "card", other: "other" }, validate: true

  belongs_to :tenant
  belongs_to :document

  validates :amount, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :paid_on, presence: true
  validate :document_must_be_invoice
  validate :document_must_belong_to_tenant

  # 入金の登録・変更・削除のたびに、請求書の入金ステータスを再計算する
  after_save :recalculate_document_payment_status
  after_destroy :recalculate_document_payment_status

  def method_label
    METHOD_LABELS[method]
  end

  private
    def recalculate_document_payment_status
      document&.recalculate_payment_status!
    end

    def document_must_be_invoice
      return if document.blank?
      return if document.invoice?

      errors.add(:document, "は請求書ではありません")
    end

    def document_must_belong_to_tenant
      return if document.blank? || tenant.blank?
      return if document.tenant_id == tenant_id

      errors.add(:document, "は自社の帳票ではありません")
    end
end

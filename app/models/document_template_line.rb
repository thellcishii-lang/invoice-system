class DocumentTemplateLine < ApplicationRecord
  enum :tax_rate, { standard: "standard", reduced: "reduced" }, validate: true

  belongs_to :document_template
  belongs_to :item, optional: true

  validates :name, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_save :calculate_amount

  private
    def calculate_amount
      self.amount = DocumentTaxCalculator.line_amount(
        quantity: quantity, unit_price: unit_price, rounding: document_template.tenant.tax_rounding
      )
    end
end

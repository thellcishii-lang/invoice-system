class DocumentLine < ApplicationRecord
  # 税率: standard=標準税率10% / reduced=軽減税率8%（品目の税率区分とスナップショットで保持）
  enum :tax_rate, { standard: "standard", reduced: "reduced" }, validate: true

  belongs_to :document
  belongs_to :item, optional: true

  validates :name, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_save :calculate_amount

  # 粗利 = 金額 − 原価（原価は社内用。帳票には印刷しない）
  def gross_profit
    amount - cost_amount
  end

  private
    # 金額 = 数量 × 単価（端数処理はテナント設定に従う。税込表示なら税込金額）
    def calculate_amount
      rounding = document.tenant.tax_rounding
      self.amount = DocumentTaxCalculator.line_amount(
        quantity: quantity, unit_price: unit_price, rounding: rounding
      )
      self.cost_amount = DocumentTaxCalculator.line_amount(
        quantity: quantity, unit_price: cost_unit_price, rounding: rounding
      )
    end
end

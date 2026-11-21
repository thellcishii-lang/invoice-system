# 帳票の金額計算。明細を税率ごとに集計し、テナントの端数処理・税表示に従って
# 税抜小計・消費税額・税込合計と、税率ごとの内訳（適格請求書の表示用）を返す。
#
# 適格請求書のルールに合わせ、端数処理は「税率グループごと」に1回だけ行う。
#
# - 税抜表示（exclusive）: 単価は税抜。明細金額 = 数量 × 単価、
#   税額 = グループ小計 × 税率。
# - 税込表示（inclusive）: 単価は税込。グループの税込合計から
#   税抜小計 = 税込合計 ÷ (1 + 税率) を逆算し、税額 = 税込合計 − 税抜小計。
class DocumentTaxCalculator
  RATES = { "standard" => Rational(10, 100), "reduced" => Rational(8, 100) }.freeze

  Result = Struct.new(:subtotal, :tax_amount, :total, :breakdown, keyword_init: true)

  # 明細1行の金額（数量 × 単価）。端数処理はテナント設定に従う。
  # 税込表示の場合は税込金額、税抜表示の場合は税抜金額になる。
  def self.line_amount(quantity:, unit_price:, rounding:)
    round_money(quantity.to_d * unit_price, rounding)
  end

  def self.round_money(value, rounding)
    case rounding.to_s
    when "floor" then value.floor
    when "ceil" then value.ceil
    else value.round # "round" = 四捨五入
    end
  end

  def initialize(tenant:, lines:)
    @tenant = tenant
    @lines = lines
  end

  def call
    breakdown = {}
    @lines.group_by { |line| line.tax_rate.to_s }.each do |tax_rate, lines|
      breakdown[tax_rate] = group_result(tax_rate, lines)
    end

    Result.new(
      subtotal: breakdown.values.sum { |group| group["subtotal"] },
      tax_amount: breakdown.values.sum { |group| group["tax"] },
      total: breakdown.values.sum { |group| group["subtotal"] + group["tax"] },
      breakdown: breakdown
    )
  end

  private
    def group_result(tax_rate, lines)
      rate = RATES.fetch(tax_rate)
      amount = lines.sum { |line| self.class.line_amount(quantity: line.quantity, unit_price: line.unit_price, rounding: @tenant.tax_rounding) }

      if @tenant.inclusive?
        subtotal = self.class.round_money(amount / (1 + rate), @tenant.tax_rounding)
        { "subtotal" => subtotal, "tax" => amount - subtotal }
      else
        { "subtotal" => amount, "tax" => self.class.round_money(amount * rate, @tenant.tax_rounding) }
      end
    end
end

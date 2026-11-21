module DocumentsHelper
  TAX_RATE_LABELS = { "standard" => "10%", "reduced" => "8%" }.freeze

  def tax_rate_label(tax_rate)
    TAX_RATE_LABELS[tax_rate.to_s]
  end

  # 数量の表示（1.50 → "1.5"、2.00 → "2" のように末尾のゼロを落とす）
  def format_quantity(quantity)
    quantity = quantity.to_d
    quantity.frac.zero? ? quantity.to_i.to_s : quantity.to_s("F")
  end
end

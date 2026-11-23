module DocumentsHelper
  TAX_RATE_LABELS = { "standard" => "10%", "reduced" => "8%" }.freeze

  # 帳票デザイン: デフォルトの帯色（種別ごと）
  DEFAULT_BAND_COLORS = {
    "estimate" => "#d2e7d0", "order" => "#e4dcf5", "invoice" => "#d2e4f6",
    "delivery" => "#f8edbe", "receipt" => "#f9dfc4"
  }.freeze
  DEFAULT_BAND_TEXT_COLORS = {
    "estimate" => "#2f5d33", "order" => "#4a3566", "invoice" => "#2f4d6e",
    "delivery" => "#6e5f24", "receipt" => "#7c4a1e"
  }.freeze

  # 背景の柄（.sheet に重ねる CSS）。色はごく薄くして本文の邪魔をしない。
  PATTERN_STYLES = {
    "dots" => "background-image: radial-gradient(circle, #dbe3ec 1.1px, transparent 1.3px); background-size: 6mm 6mm;",
    "diagonal" => "background-image: repeating-linear-gradient(45deg, #eef2f7 0, #eef2f7 1.6mm, transparent 1.6mm, transparent 5mm);",
    "grid" => "background-image: linear-gradient(#edf1f6 1px, transparent 1px), linear-gradient(90deg, #edf1f6 1px, transparent 1px); background-size: 6mm 6mm;"
  }.freeze

  # 帯の背景色: カスタム色があればその淡色、なければ種別ごとのデフォルト
  def band_color_for(document)
    color = document.tenant.document_color
    return DEFAULT_BAND_COLORS[document.kind_value] if color.blank?

    mix_hex(color, "#ffffff", 0.82)
  end

  def band_text_color_for(document)
    color = document.tenant.document_color
    return DEFAULT_BAND_TEXT_COLORS[document.kind_value] if color.blank?

    mix_hex(color, "#000000", 0.30)
  end

  def document_pattern_style(tenant)
    PATTERN_STYLES[tenant.document_pattern]
  end

  # 2色を混ぜる（ratio は target 側の割合）
  def mix_hex(hex, target, ratio)
    from = hex.delete("#").scan(/../).map { |pair| pair.to_i(16) }
    to = target.delete("#").scan(/../).map { |pair| pair.to_i(16) }
    mixed = from.zip(to).map { |a, b| (a + (b - a) * ratio).round.clamp(0, 255) }
    format("#%02x%02x%02x", *mixed)
  end

  def tax_rate_label(tax_rate)
    TAX_RATE_LABELS[tax_rate.to_s]
  end

  # 数量の表示（1.50 → "1.5"、2.00 → "2" のように末尾のゼロを落とす）
  def format_quantity(quantity)
    quantity = quantity.to_d
    quantity.frac.zero? ? quantity.to_i.to_s : quantity.to_s("F")
  end
end

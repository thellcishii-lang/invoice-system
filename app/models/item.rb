class Item < ApplicationRecord
  # 品目コード: "I" + 6桁ゼロ埋め（例: I000001）。テナントごとに自動採番し、
  # 採番済みの番号は再利用しない（tenants.item_code_counter で単調増加を保証）。
  CODE_PREFIX = "I"
  CODE_FORMAT = "#{CODE_PREFIX}%06d"

  # 税率: standard=標準税率10% / reduced=軽減税率8%
  enum :tax_rate, { standard: "standard", reduced: "reduced" }, validate: true

  belongs_to :tenant
  belongs_to :item_category, optional: true

  # 品番: 分類コードの後ろに「分類の中での連番（3桁）」を付けたもの。
  # 全セグメントが3桁で揃う。例: 4階層目の分類の品目 → A001-001001001042
  # 未分類の品目は品目コードの数字部分のみ。
  # セグメントは分類ごとに自動採番・再利用なし。分類を変えたら新しい分類で採番し直す。
  before_save :assign_segment, if: -> { item_category.present? && (segment.blank? || item_category_id_changed?) }
  before_save :clear_segment, if: -> { item_category.blank? && segment.present? }

  def part_number
    return code.to_s.delete_prefix(CODE_PREFIX) if item_category.blank?

    "#{item_category.full_code}#{segment}"
  end

  scope :active, -> { where(active: true) }

  before_validation :assign_code, on: :create

  validates :name, presence: true
  validates :code, presence: true, uniqueness: { scope: :tenant_id }
  validates :unit_price, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  private
    def assign_segment
      item_category.with_lock do
        item_category.increment!(:item_segment_counter)
        self.segment = format("%03d", item_category.item_segment_counter)
      end
    end

    def clear_segment
      self.segment = nil
    end

    def assign_code
      return if code.present?
      return if tenant.blank?

      tenant.with_lock do
        tenant.increment!(:item_code_counter)
        self.code = format(CODE_FORMAT, tenant.item_code_counter)
      end
    end
end

class Item < ApplicationRecord
  # 品目コード: "I" + 6桁ゼロ埋め（例: I000001）。テナントごとに自動採番し、
  # 採番済みの番号は再利用しない（tenants.item_code_counter で単調増加を保証）。
  CODE_PREFIX = "I"
  CODE_FORMAT = "#{CODE_PREFIX}%06d"

  # 税率: standard=標準税率10% / reduced=軽減税率8%
  enum :tax_rate, { standard: "standard", reduced: "reduced" }, validate: true

  belongs_to :tenant
  belongs_to :item_category, optional: true

  scope :active, -> { where(active: true) }

  before_validation :assign_code, on: :create

  validates :name, presence: true
  validates :code, presence: true, uniqueness: { scope: :tenant_id }
  validates :unit_price, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  private
    def assign_code
      return if code.present?
      return if tenant.blank?

      tenant.with_lock do
        tenant.increment!(:item_code_counter)
        self.code = format(CODE_FORMAT, tenant.item_code_counter)
      end
    end
end

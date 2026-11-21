class Tenant < ApplicationRecord
  MAX_MEMBERS = 5

  # 端数処理: floor=切り捨て / round=四捨五入 / ceil=切り上げ
  enum :tax_rounding, { floor: "floor", round: "round", ceil: "ceil" }, validate: true
  # 税表示: exclusive=税抜 / inclusive=税込
  enum :tax_display, { exclusive: "exclusive", inclusive: "inclusive" }, validate: true

  has_many :users, dependent: :restrict_with_error
  has_many :clients, dependent: :restrict_with_error
  has_many :items, dependent: :restrict_with_error
  has_many :documents, dependent: :restrict_with_error
  has_many :document_sequences, dependent: :restrict_with_error
  has_many :document_deliveries, dependent: :restrict_with_error
  has_many :recurring_documents, dependent: :restrict_with_error
  has_many :payments, dependent: :restrict_with_error

  validates :name, presence: true

  def member_limit_reached?
    users.count >= MAX_MEMBERS
  end
end

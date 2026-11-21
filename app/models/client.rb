class Client < ApplicationRecord
  belongs_to :tenant

  scope :active, -> { where(archived: false) }

  validates :name, presence: true
end

class User < ApplicationRecord
  belongs_to :tenant
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true
  validate :tenant_member_limit_not_exceeded, on: :create

  private
    def tenant_member_limit_not_exceeded
      return if tenant.blank?
      return unless tenant.member_limit_reached?

      errors.add(:base, "メンバーは最大#{Tenant::MAX_MEMBERS}名までです")
    end
end

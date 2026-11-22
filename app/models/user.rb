class User < ApplicationRecord
  belongs_to :tenant
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true
  validate :tenant_member_limit_not_exceeded, on: :create

  # 申込時の招待メール用パスワード設定リンク。署名付きIDで72時間有効。
  # パスワード自体はメールに載せない。
  PASSWORD_SETUP_PURPOSE = "password_setup"
  PASSWORD_SETUP_TTL = 72.hours

  def password_setup_token
    signed_id(purpose: PASSWORD_SETUP_PURPOSE, expires_in: PASSWORD_SETUP_TTL)
  end

  # 署名が不正・期限切れの場合は nil を返す
  def self.find_by_password_setup_token(token)
    find_signed(token, purpose: PASSWORD_SETUP_PURPOSE)
  end

  private
    def tenant_member_limit_not_exceeded
      return if tenant.blank?
      return unless tenant.member_limit_reached?

      errors.add(:base, "メンバーは最大#{Tenant::MAX_MEMBERS}名までです")
    end
end

# 公開申込フォームからの申込。Stripe Checkout の決済完了（Webhook）で
# テナントと最初のユーザーを発行し、completed になる。
class SignupApplication < ApplicationRecord
  enum :status, { pending: "pending", completed: "completed" }, validate: true

  belongs_to :tenant, optional: true

  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :company_name, presence: true
  validates :contact_name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :agreed_to_terms, acceptance: { message: "への同意が必要です" }
end

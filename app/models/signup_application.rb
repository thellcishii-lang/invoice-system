# 公開申込フォームからの申込。Stripe Checkout の決済完了（Webhook）で
# テナントと最初のユーザーを発行し、completed になる。
class SignupApplication < ApplicationRecord
  # 月額料金（税別）。2026-11-24 決定（一般・建築とも同額）。実際の課金は Stripe の価格ID側で行う。
  PRICE_TAX_EXCLUDED = { "general" => 2500, "construction" => 2500 }.freeze

  enum :status, { pending: "pending", completed: "completed" }, validate: true

  belongs_to :tenant, optional: true

  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :edition, inclusion: { in: Tenant::EDITIONS }
  validates :company_name, presence: true
  validates :contact_name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :agreed_to_terms, acceptance: { message: "への同意が必要です" }

  def construction?
    edition == "construction"
  end

  # この申込の月額料金（税別）
  def price_tax_excluded
    PRICE_TAX_EXCLUDED.fetch(edition)
  end
end

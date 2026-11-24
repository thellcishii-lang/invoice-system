# 公開申込フォームからの申込。Stripe Checkout の決済完了（Webhook）で
# テナントと最初のユーザーを発行し、completed になる。
class SignupApplication < ApplicationRecord
  # 月額料金（税別）。2026-11-24 決定（一般・建築とも同額）。実際の課金は Stripe の価格ID側で行う。
  PRICE_TAX_EXCLUDED = { "general" => 2500, "construction" => 2500 }.freeze
  # 年額料金（税別）。月額×10（2ヶ月分お得）。2026-11-24 決定。
  YEARLY_PRICE_TAX_EXCLUDED = 25_000

  enum :status, { pending: "pending", completed: "completed" }, validate: true
  enum :billing_interval, { monthly: "monthly", yearly: "yearly" }, validate: true

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

  # 選択した支払いプランの金額（税別）。年払いは YEARLY_PRICE_TAX_EXCLUDED。
  def plan_price_tax_excluded
    yearly? ? YEARLY_PRICE_TAX_EXCLUDED : price_tax_excluded
  end

  def billing_interval_label
    yearly? ? "年払い" : "月払い"
  end
end

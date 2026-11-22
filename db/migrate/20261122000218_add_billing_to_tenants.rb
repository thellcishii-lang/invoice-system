class AddBillingToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :stripe_customer_id, :string
    add_column :tenants, :stripe_subscription_id, :string
    # 課金状態: none=未契約 / active=契約中 / suspended=停止中 / cancelled=解約済み
    add_column :tenants, :billing_status, :string, default: "none", null: false
    add_column :tenants, :contract_ended_at, :datetime
    # その月に作成できる請求書の上限。NULL は無制限（自社テナント用）
    add_column :tenants, :monthly_invoice_limit, :integer, default: 100

    add_index :tenants, :stripe_customer_id
    add_index :tenants, :stripe_subscription_id
  end
end

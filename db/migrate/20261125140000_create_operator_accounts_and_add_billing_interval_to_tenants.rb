class CreateOperatorAccountsAndAddBillingIntervalToTenants < ActiveRecord::Migration[8.1]
  def change
    create_table :operator_accounts do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.timestamps
    end
    add_index :operator_accounts, :email, unique: true

    add_column :tenants, :billing_interval, :string, default: "monthly", null: false

    reversible do |dir|
      # 既存テナントには、紐づく申込のプラン区分を引き継ぐ
      dir.up do
        execute <<~SQL
          UPDATE tenants
          SET billing_interval = (
            SELECT billing_interval FROM signup_applications
            WHERE signup_applications.tenant_id = tenants.id
            ORDER BY signup_applications.id LIMIT 1
          )
          WHERE EXISTS (
            SELECT 1 FROM signup_applications
            WHERE signup_applications.tenant_id = tenants.id
          )
        SQL
      end
    end
  end
end

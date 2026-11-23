class AddBankFieldsToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :bank_name, :string
    add_column :tenants, :bank_branch, :string
    add_column :tenants, :bank_account_type, :string
    add_column :tenants, :bank_account_number, :string
    add_column :tenants, :bank_account_holder, :string
  end
end

class AddSmtpSettingsToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :smtp_host, :string
    add_column :tenants, :smtp_port, :integer, null: false, default: 587
    add_column :tenants, :smtp_username, :string
    add_column :tenants, :smtp_password_ciphertext, :text
    add_column :tenants, :smtp_from_address, :string
  end
end

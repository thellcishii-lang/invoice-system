class AddSealAndBankDetailsToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :seal_image_data, :text
    add_column :tenants, :seal_image_content_type, :string
    add_column :tenants, :bank_details, :text
  end
end

class AddLogoToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :logo_image_data, :text
    add_column :tenants, :logo_image_content_type, :string
    add_column :tenants, :logo_placement, :string
    add_column :tenants, :logo_alignment, :string
  end
end

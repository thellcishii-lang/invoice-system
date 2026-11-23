class AddDocumentDesignToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :document_color, :string
    add_column :tenants, :document_striped, :boolean, null: false, default: false
    add_column :tenants, :document_pattern, :string, null: false, default: "none"
  end
end

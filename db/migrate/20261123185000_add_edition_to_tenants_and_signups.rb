class AddEditionToTenantsAndSignups < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :edition, :string, null: false, default: "general"
    add_column :signup_applications, :edition, :string, null: false, default: "general"
  end
end

class AddEnvelopeSettingsToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :envelope_size, :string, default: "chou4", null: false
    add_column :tenants, :envelope_direction, :string, default: "horizontal", null: false
    add_column :tenants, :envelope_sender, :boolean, default: true, null: false
    add_column :tenants, :envelope_logo, :boolean, default: false, null: false
  end
end

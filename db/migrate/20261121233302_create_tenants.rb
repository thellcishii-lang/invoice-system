class CreateTenants < ActiveRecord::Migration[8.1]
  def change
    create_table :tenants do |t|
      t.string :name, null: false
      t.string :invoice_registration_number
      t.string :postal_code
      t.string :address
      t.string :phone
      t.string :email
      t.string :document_number_prefix, null: false, default: ""
      t.string :tax_rounding, null: false, default: "floor"
      t.string :tax_display, null: false, default: "exclusive"

      t.timestamps
    end
  end
end

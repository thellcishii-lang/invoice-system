class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.integer :unit_price, default: 0, null: false
      t.string :unit
      t.string :tax_rate, default: "standard", null: false
      t.text :description
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :items, %i[ tenant_id code ], unique: true
  end
end

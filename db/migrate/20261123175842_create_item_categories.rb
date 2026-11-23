class CreateItemCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :item_categories do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :item_categories }
      t.string :name, null: false
      t.text :note
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_reference :items, :item_category, foreign_key: true
  end
end

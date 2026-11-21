class CreateDocumentLines < ActiveRecord::Migration[8.1]
  def change
    create_table :document_lines do |t|
      t.references :document, null: false, foreign_key: true
      t.references :item, foreign_key: true
      t.string :name, null: false
      t.decimal :quantity, precision: 12, scale: 2, null: false
      t.string :unit
      t.integer :unit_price, default: 0, null: false
      t.string :tax_rate, default: "standard", null: false
      t.integer :position, default: 0, null: false
      t.integer :amount, default: 0, null: false

      t.timestamps
    end
  end
end

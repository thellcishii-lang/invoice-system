class CreateDocumentTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :document_templates do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :name, null: false
      t.string :title
      t.text :notes
      t.timestamps
    end

    create_table :document_template_lines do |t|
      t.references :document_template, null: false, foreign_key: true
      t.references :item, foreign_key: true
      t.string :name, null: false
      t.decimal :quantity, precision: 12, scale: 2, null: false
      t.string :unit
      t.integer :unit_price, null: false, default: 0
      t.string :tax_rate, null: false, default: "standard"
      t.integer :position, null: false, default: 0
      t.integer :amount, null: false, default: 0
      t.timestamps
    end
  end
end

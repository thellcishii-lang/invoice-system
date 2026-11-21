class CreateDocumentSequences < ActiveRecord::Migration[8.1]
  def change
    create_table :document_sequences do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :year_month, null: false
      t.integer :last_number, default: 0, null: false

      t.timestamps
    end

    add_index :document_sequences, %i[ tenant_id kind year_month ], unique: true
  end
end

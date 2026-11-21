class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :number, null: false
      t.date :issue_date, null: false
      t.date :due_date
      t.string :title
      t.string :status, default: "draft", null: false
      t.text :notes
      t.references :converted_from, foreign_key: { to_table: :documents }
      t.integer :subtotal, default: 0, null: false
      t.integer :tax_amount, default: 0, null: false
      t.integer :total, default: 0, null: false
      t.jsonb :tax_breakdown, default: {}, null: false

      t.timestamps
    end

    add_index :documents, %i[ tenant_id kind ]
    # 帳票番号は「テナント × 種別」の中で一意（連番は種別・月ごとに振るため）
    add_index :documents, %i[ tenant_id kind number ], unique: true
  end
end

class CreateRecurringDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :recurring_documents do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.references :template_document, null: false, foreign_key: { to_table: :documents }
      t.integer :day_of_month, null: false
      t.boolean :active, default: true, null: false
      t.boolean :auto_send, default: false, null: false
      t.date :last_run_date
      t.date :next_run_date, null: false

      t.timestamps
    end
  end
end

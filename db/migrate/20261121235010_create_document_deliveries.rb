class CreateDocumentDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :document_deliveries do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true
      t.string :channel, null: false
      t.string :recipient_email, null: false
      t.datetime :sent_at, null: false
      t.string :token_digest

      t.timestamps
    end
  end
end

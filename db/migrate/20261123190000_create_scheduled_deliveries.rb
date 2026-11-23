class CreateScheduledDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :scheduled_deliveries do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true
      t.references :send_template, foreign_key: true
      t.string :channel, null: false
      t.string :recipient, null: false
      t.datetime :scheduled_at, null: false
      t.string :status, null: false, default: "pending"
      t.string :error_message
      t.datetime :sent_at

      t.timestamps
    end
    add_index :scheduled_deliveries, [ :status, :scheduled_at ]
  end
end

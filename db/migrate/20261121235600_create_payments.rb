class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true
      t.integer :amount, null: false
      t.date :paid_on, null: false
      t.string :method, null: false
      t.text :note

      t.timestamps
    end
  end
end

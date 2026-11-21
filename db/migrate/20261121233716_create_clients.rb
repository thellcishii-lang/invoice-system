class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name, null: false
      t.string :name_kana
      t.string :postal_code
      t.string :address
      t.string :phone
      t.string :email
      t.string :contact_person
      t.text :payment_terms
      t.string :registration_number
      t.boolean :archived, default: false, null: false

      t.timestamps
    end
  end
end

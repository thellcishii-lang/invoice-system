class CreateSignupApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :signup_applications do |t|
      t.string :company_name, null: false
      t.string :contact_name, null: false
      t.string :email, null: false
      t.boolean :agreed_to_terms, default: false, null: false
      t.string :stripe_checkout_session_id
      # pending=申込受付済み（決済待ち） / completed=テナント発行済み
      t.string :status, default: "pending", null: false
      t.references :tenant, null: true, foreign_key: true

      t.timestamps
    end

    add_index :signup_applications, :stripe_checkout_session_id, unique: true
  end
end

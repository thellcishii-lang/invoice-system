class AddBillingIntervalToSignupApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :signup_applications, :billing_interval, :string, default: "monthly", null: false
  end
end

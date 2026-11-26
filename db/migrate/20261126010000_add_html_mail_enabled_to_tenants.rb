class AddHtmlMailEnabledToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :html_mail_enabled, :boolean, default: false, null: false
  end
end

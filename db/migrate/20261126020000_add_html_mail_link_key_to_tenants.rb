class AddHtmlMailLinkKeyToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :html_mail_link_key_ciphertext, :text
  end
end

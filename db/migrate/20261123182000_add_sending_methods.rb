class AddSendingMethods < ActiveRecord::Migration[8.1]
  def up
    add_column :clients, :fax_number, :string

    # 定期請求: auto_send（メールのみ）→ send_method（none/email/fax）
    add_column :recurring_documents, :send_method, :string, null: false, default: "none"
    execute "UPDATE recurring_documents SET send_method = 'email' WHERE auto_send = TRUE"
    remove_column :recurring_documents, :auto_send

    # 送信履歴: 成功だけでなく失敗（送信不可）も記録できるようにする
    add_column :document_deliveries, :status, :string, null: false, default: "sent"
    add_column :document_deliveries, :recipient, :string
    add_column :document_deliveries, :error_message, :text
    execute "UPDATE document_deliveries SET recipient = recipient_email"
    change_column_null :document_deliveries, :recipient_email, true
    change_column_null :document_deliveries, :sent_at, true
  end

  def down
    remove_column :clients, :fax_number
    add_column :recurring_documents, :auto_send, :boolean, null: false, default: false
    execute "UPDATE recurring_documents SET auto_send = TRUE WHERE send_method = 'email'"
    remove_column :recurring_documents, :send_method
    remove_column :document_deliveries, :status
    remove_column :document_deliveries, :recipient
    remove_column :document_deliveries, :error_message
    change_column_null :document_deliveries, :recipient_email, false
    change_column_null :document_deliveries, :sent_at, false
  end
end

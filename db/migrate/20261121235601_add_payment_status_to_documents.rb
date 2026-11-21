class AddPaymentStatusToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :payment_status, :string

    # 既存の請求書は「未入金」を初期値にする（請求書以外は NULL のまま）
    reversible do |dir|
      dir.up do
        execute "UPDATE documents SET payment_status = 'unpaid' WHERE kind = 'invoice'"
      end
    end
  end
end

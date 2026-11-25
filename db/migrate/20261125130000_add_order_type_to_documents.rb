class AddOrderTypeToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :order_type, :string

    reversible do |dir|
      # 既存の発注書は販売の流れ（見積からの変換）で作られたものとして「受注」に寄せる
      dir.up { execute "UPDATE documents SET order_type = 'received' WHERE kind = 'order'" }
    end
  end
end

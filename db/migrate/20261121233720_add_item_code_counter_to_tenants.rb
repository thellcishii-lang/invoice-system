class AddItemCodeCounterToTenants < ActiveRecord::Migration[8.1]
  def change
    # 品目コードの採番カウンタ（テナントごとに単調増加、再利用しない）
    add_column :tenants, :item_code_counter, :integer, default: 0, null: false
  end
end

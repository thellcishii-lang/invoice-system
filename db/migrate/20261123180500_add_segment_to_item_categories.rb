class AddSegmentToItemCategories < ActiveRecord::Migration[8.1]
  def up
    add_column :item_categories, :segment, :string
    add_column :item_categories, :child_segment_counter, :integer, null: false, default: 0
    add_column :tenants, :item_category_counter, :integer, null: false, default: 0

    # 既存の分類にセグメント（親の中での3桁番号）を並び順に割り当て、
    # カウンタを割り当て済みの数に合わせる（番号は再利用しない）
    category_class = Class.new(ApplicationRecord) { self.table_name = "item_categories" }
    tenant_class = Class.new(ApplicationRecord) { self.table_name = "tenants" }

    category_class.where(parent_id: nil).order(:position, :id).group_by(&:tenant_id).each do |tenant_id, roots|
      roots.each_with_index { |c, i| c.update_columns(segment: format("%03d", i + 1)) }
      tenant_class.where(id: tenant_id).update_all(item_category_counter: roots.size)
    end
    category_class.where.not(parent_id: nil).order(:position, :id).group_by(&:parent_id).each do |parent_id, children|
      children.each_with_index { |c, i| c.update_columns(segment: format("%03d", i + 1)) }
      category_class.where(id: parent_id).update_all(child_segment_counter: children.size)
    end
  end

  def down
    remove_column :item_categories, :segment
    remove_column :item_categories, :child_segment_counter
    remove_column :tenants, :item_category_counter
  end
end

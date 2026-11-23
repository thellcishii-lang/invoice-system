class AddItemSegment < ActiveRecord::Migration[8.1]
  def up
    add_column :item_categories, :item_segment_counter, :integer, null: false, default: 0
    add_column :items, :segment, :string

    # 既存の分類付き品目に、分類ごとの連番（3桁）を割り当てる
    item_class = Class.new(ApplicationRecord) { self.table_name = "items" }
    category_class = Class.new(ApplicationRecord) { self.table_name = "item_categories" }
    item_class.where.not(item_category_id: nil).order(:id).group_by(&:item_category_id).each do |category_id, items|
      items.each_with_index { |item, i| item.update_columns(segment: format("%03d", i + 1)) }
      category_class.where(id: category_id).update_all(item_segment_counter: items.size)
    end
  end

  def down
    remove_column :item_categories, :item_segment_counter
    remove_column :items, :segment
  end
end

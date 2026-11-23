class RemoveNoteFromItemCategories < ActiveRecord::Migration[8.1]
  def change
    remove_column :item_categories, :note, :text
  end
end

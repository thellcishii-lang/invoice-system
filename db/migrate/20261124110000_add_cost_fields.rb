class AddCostFields < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :cost_price, :integer
    add_column :document_lines, :cost_unit_price, :integer, null: false, default: 0
    add_column :document_lines, :cost_amount, :integer, null: false, default: 0
    add_column :document_template_lines, :cost_unit_price, :integer, null: false, default: 0
    add_column :document_template_lines, :cost_amount, :integer, null: false, default: 0
  end
end

require "test_helper"

class GrossProfitTest < ActiveSupport::TestCase
  test "line cost amount and document gross profit (tax-exclusive tenant)" do
    tenant = tenants(:one) # tax_display: exclusive
    client = tenant.clients.create!(name: "粗利テスト商事")
    document = tenant.documents.build(kind: "estimate", client: client, title: "粗利テスト",
                                      issue_date: Date.current, status: "draft")
    document.document_lines.build(name: "工事", quantity: 2, unit_price: 50000, cost_unit_price: 30000)
    document.document_lines.build(name: "材料", quantity: 1, unit_price: 10000, cost_unit_price: 12000)
    document.save!
    document.recalculate_totals!

    line = document.document_lines.first
    assert_equal 60000, line.cost_amount
    assert_equal 40000, line.gross_profit

    assert_equal 72000, document.cost_total
    assert_equal 110000, document.sales_basis # 小計（税抜）
    assert_equal 38000, document.gross_profit
    assert_in_delta 34.5, document.gross_margin_rate, 0.1
  end

  test "cost is carried over on duplicate and conversion" do
    tenant = tenants(:one)
    client = tenant.clients.create!(name: "引き継ぎ商事")
    document = tenant.documents.build(kind: "estimate", client: client, title: "t",
                                      issue_date: Date.current, status: "draft")
    document.document_lines.build(name: "作業", quantity: 1, unit_price: 80000, cost_unit_price: 50000)
    document.save!

    copy = document.duplicate!
    assert_equal 50000, copy.document_lines.first.cost_unit_price

    invoice = document.convert_to("invoice")
    assert_equal 50000, invoice.document_lines.first.cost_unit_price
  end

  test "item cost price is the master default for lines" do
    item = tenants(:one).items.create!(name: "部材A", unit_price: 10000, cost_price: 6500)
    assert_equal 6500, item.cost_price
  end
end

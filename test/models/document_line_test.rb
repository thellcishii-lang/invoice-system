require "test_helper"

class DocumentLineTest < ActiveSupport::TestCase
  test "amount is quantity times unit price" do
    line = documents(:invoice_one).document_lines.build(
      name: "追加作業", quantity: 2, unit_price: 1500, tax_rate: "standard"
    )
    line.save!

    assert_equal 3000, line.amount
  end

  test "amount truncates fractions with floor rounding tenant" do
    # テナント one は切り捨て: 1.5 × 999 = 1498.5 → 1498
    line = documents(:invoice_one).document_lines.build(
      name: "時間作業", quantity: 1.5, unit_price: 999, tax_rate: "standard"
    )
    line.save!

    assert_equal 1498, line.amount
  end

  test "amount rounds with round rounding tenant" do
    # テナント two は四捨五入: 1.5 × 999 = 1498.5 → 1499
    line = documents(:invoice_two).document_lines.build(
      name: "時間作業", quantity: 1.5, unit_price: 999, tax_rate: "standard"
    )
    line.save!

    assert_equal 1499, line.amount
  end

  test "item reference is optional" do
    line = documents(:invoice_one).document_lines.build(
      name: "フリー入力", quantity: 1, unit_price: 500, tax_rate: "reduced"
    )

    assert line.valid?
    assert_nil line.item
  end
end

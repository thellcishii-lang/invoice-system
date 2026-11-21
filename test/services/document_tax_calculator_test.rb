require "test_helper"

class DocumentTaxCalculatorTest < ActiveSupport::TestCase
  def calculate(tenant:, lines:)
    DocumentTaxCalculator.new(tenant: tenant, lines: lines).call
  end

  def tenant(rounding:, display:)
    Tenant.new(tax_rounding: rounding, tax_display: display)
  end

  def line(quantity:, unit_price:, tax_rate: "standard")
    DocumentLine.new(quantity: quantity, unit_price: unit_price, tax_rate: tax_rate)
  end

  test "exclusive: groups lines by tax rate and taxes each group" do
    result = calculate(
      tenant: tenant(rounding: "floor", display: "exclusive"),
      lines: [
        line(quantity: 1, unit_price: 39800),
        line(quantity: 1, unit_price: 4000, tax_rate: "reduced")
      ]
    )

    assert_equal 43800, result.subtotal
    assert_equal 4300, result.tax_amount
    assert_equal 48100, result.total
    assert_equal({ "subtotal" => 39800, "tax" => 3980 }, result.breakdown["standard"])
    assert_equal({ "subtotal" => 4000, "tax" => 320 }, result.breakdown["reduced"])
  end

  test "exclusive: floor rounding truncates tax per group" do
    result = calculate(
      tenant: tenant(rounding: "floor", display: "exclusive"),
      lines: [ line(quantity: 1, unit_price: 999) ]
    )

    assert_equal 999, result.subtotal
    assert_equal 99, result.tax_amount
    assert_equal 1098, result.total
  end

  test "exclusive: round rounding rounds tax half up" do
    result = calculate(
      tenant: tenant(rounding: "round", display: "exclusive"),
      lines: [ line(quantity: 1, unit_price: 999) ]
    )

    assert_equal 100, result.tax_amount
  end

  test "exclusive: round rounding rounds down below half" do
    result = calculate(
      tenant: tenant(rounding: "round", display: "exclusive"),
      lines: [ line(quantity: 1, unit_price: 994) ]
    )

    assert_equal 99, result.tax_amount
  end

  test "exclusive: ceil rounding rounds tax up" do
    result = calculate(
      tenant: tenant(rounding: "ceil", display: "exclusive"),
      lines: [ line(quantity: 1, unit_price: 994) ]
    )

    assert_equal 100, result.tax_amount
  end

  test "exclusive: fractional quantity multiplies through" do
    result = calculate(
      tenant: tenant(rounding: "floor", display: "exclusive"),
      lines: [ line(quantity: 2.5, unit_price: 1000) ]
    )

    assert_equal 2500, result.subtotal
    assert_equal 250, result.tax_amount
    assert_equal 2750, result.total
  end

  test "exclusive: line amounts are rounded with the tenant rounding" do
    floor_result = calculate(
      tenant: tenant(rounding: "floor", display: "exclusive"),
      lines: [ line(quantity: 1.5, unit_price: 999) ]
    )
    assert_equal 1498, floor_result.subtotal
    assert_equal 149, floor_result.tax_amount

    round_result = calculate(
      tenant: tenant(rounding: "round", display: "exclusive"),
      lines: [ line(quantity: 1.5, unit_price: 999) ]
    )
    assert_equal 1499, round_result.subtotal
    assert_equal 150, round_result.tax_amount
  end

  test "inclusive: derives ex-tax subtotal and tax from gross amounts" do
    result = calculate(
      tenant: tenant(rounding: "round", display: "inclusive"),
      lines: [
        line(quantity: 1, unit_price: 11000),
        line(quantity: 1, unit_price: 1080, tax_rate: "reduced")
      ]
    )

    assert_equal 11000, result.subtotal
    assert_equal 1080, result.tax_amount
    assert_equal 12080, result.total
    assert_equal({ "subtotal" => 10000, "tax" => 1000 }, result.breakdown["standard"])
    assert_equal({ "subtotal" => 1000, "tax" => 80 }, result.breakdown["reduced"])
  end

  test "inclusive: floor rounding applies to the derived subtotal" do
    result = calculate(
      tenant: tenant(rounding: "floor", display: "inclusive"),
      lines: [ line(quantity: 1, unit_price: 100) ]
    )

    assert_equal 90, result.subtotal
    assert_equal 10, result.tax_amount
    assert_equal 100, result.total
  end

  test "inclusive: ceil rounding applies to the derived subtotal" do
    result = calculate(
      tenant: tenant(rounding: "ceil", display: "inclusive"),
      lines: [ line(quantity: 1, unit_price: 100) ]
    )

    assert_equal 91, result.subtotal
    assert_equal 9, result.tax_amount
    assert_equal 100, result.total
  end

  test "empty lines produce zero totals" do
    result = calculate(tenant: tenant(rounding: "floor", display: "exclusive"), lines: [])

    assert_equal 0, result.subtotal
    assert_equal 0, result.tax_amount
    assert_equal 0, result.total
    assert_equal({}, result.breakdown)
  end
end

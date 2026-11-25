require "test_helper"

class UnitTest < ActiveSupport::TestCase
  test "names_for seeds the default units on first use" do
    tenant = tenants(:one)
    assert_equal 0, tenant.units.count

    names = Unit.names_for(tenant)

    assert_equal Unit::DEFAULT_NAMES, names
    assert_equal Unit::DEFAULT_NAMES.size, tenant.units.count
  end

  test "names_for does not duplicate defaults on a second call" do
    tenant = tenants(:one)
    Unit.names_for(tenant)

    assert_no_difference("Unit.count") do
      assert_equal Unit::DEFAULT_NAMES, Unit.names_for(tenant)
    end
  end

  test "unit names are unique per tenant but can repeat across tenants" do
    tenants(:one).units.create!(name: "個")

    assert tenants(:two).units.build(name: "個").valid?
    assert_not tenants(:one).units.build(name: "個").valid?
  end
end

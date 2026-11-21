require "test_helper"

class ItemTest < ActiveSupport::TestCase
  test "code is auto-assigned starting at I000001 for a new tenant" do
    tenant = Tenant.create!(name: "新規テナント")

    first = tenant.items.create!(name: "品目A", unit_price: 100)
    second = tenant.items.create!(name: "品目B", unit_price: 200)

    assert_equal "I000001", first.code
    assert_equal "I000002", second.code
  end

  test "codes increase monotonically and are never reused after destroy" do
    tenant = tenants(:one)
    # fixture: tenant one already has I000001, I000002 (counter = 2)

    item = tenant.items.create!(name: "品目C", unit_price: 300)
    assert_equal "I000003", item.code

    item.destroy!

    next_item = tenant.items.create!(name: "品目D", unit_price: 400)
    assert_equal "I000004", next_item.code
  end

  test "code must be unique within a tenant" do
    duplicate = tenants(:one).items.build(name: "重複品目", unit_price: 100, code: items(:one).code)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], "has already been taken"
  end

  test "same code is allowed in another tenant" do
    # I000002 はテナント one にだけ存在するコード
    other = tenants(:two).items.build(name: "別テナント品目", unit_price: 100, code: items(:two).code)

    assert other.valid?
  end

  test "tax_rate accepts standard and reduced" do
    assert tenants(:one).items.build(name: "標準品目", unit_price: 100, tax_rate: "standard").valid?
    assert tenants(:one).items.build(name: "軽減品目", unit_price: 100, tax_rate: "reduced").valid?
  end

  test "tax_rate rejects invalid values" do
    # enum の validate: true により、不正値は代入できてもバリデーションで弾く
    item = tenants(:one).items.build(name: "不正な税率", unit_price: 100, tax_rate: "exempt")

    assert_not item.valid?
    assert_includes item.errors[:tax_rate], "is not included in the list"
  end

  test "unit_price must be a non-negative integer" do
    item = tenants(:one).items.build(name: "負の単価", unit_price: -1)

    assert_not item.valid?
    assert_includes item.errors[:unit_price], "must be greater than or equal to 0"
  end

  test "requires a name" do
    item = tenants(:one).items.build(name: "", unit_price: 100)

    assert_not item.valid?
    assert_includes item.errors[:name], "can't be blank"
  end

  test "active scope excludes inactive items" do
    active_items = tenants(:one).items.active

    assert_includes active_items, items(:one)
    assert_not_includes active_items, items(:two)
  end
end

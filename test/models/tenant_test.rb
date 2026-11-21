require "test_helper"

class TenantTest < ActiveSupport::TestCase
  test "default settings are applied on create" do
    tenant = Tenant.create!(name: "デフォルト確認株式会社")

    assert_equal "", tenant.document_number_prefix
    assert_equal "floor", tenant.tax_rounding
    assert_equal "exclusive", tenant.tax_display
  end

  test "name is required" do
    tenant = Tenant.new(name: "")

    assert_not tenant.valid?
    assert tenant.errors[:name].present?
  end

  test "member_limit_reached? is true at 5 members" do
    tenant = tenants(:one)
    assert_not tenant.member_limit_reached?

    4.times do |i|
      tenant.users.create!(name: "追加メンバー#{i}", email_address: "extra#{i}@example.co.jp", password: "password")
    end

    assert_equal Tenant::MAX_MEMBERS, tenant.users.count
    assert tenant.member_limit_reached?
  end
end

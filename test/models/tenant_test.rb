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
end

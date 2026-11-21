require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "sixth member of a tenant is rejected" do
    tenant = Tenant.create!(name: "上限テスト株式会社")

    Tenant::MAX_MEMBERS.times do |i|
      tenant.users.create!(name: "メンバー#{i + 1}", email_address: "member#{i + 1}@example.co.jp", password: "password")
    end

    sixth = tenant.users.build(name: "6人目", email_address: "member6@example.co.jp", password: "password")

    assert_not sixth.valid?
    assert_not sixth.save
    assert_equal Tenant::MAX_MEMBERS, tenant.users.count
  end

  test "member limit is per tenant" do
    tenant_one = tenants(:one)
    Tenant::MAX_MEMBERS.times do |i|
      break if tenant_one.users.count >= Tenant::MAX_MEMBERS
      tenant_one.users.create!(name: "補充#{i}", email_address: "fill#{i}@example.co.jp", password: "password")
    end
    assert tenant_one.member_limit_reached?

    other = tenants(:two).users.build(name: "他社メンバー", email_address: "other@example.co.jp", password: "password")
    assert other.valid?
  end
end

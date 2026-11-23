require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "members are unlimited" do
    tenant = Tenant.create!(name: "無制限テスト株式会社")

    8.times do |i|
      tenant.users.create!(name: "メンバー#{i + 1}", email_address: "member#{i + 1}@example.co.jp", password: "password")
    end

    assert_equal 8, tenant.users.count
  end
end

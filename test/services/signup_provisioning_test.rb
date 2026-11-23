require "test_helper"

class SignupProvisioningTest < ActiveSupport::TestCase
  test "provisions a tenant with the application's edition" do
    application = SignupApplication.create!(
      company_name: "テスト建設", contact_name: "山田", email: "yamada@example.co.jp",
      agreed_to_terms: true, edition: "construction"
    )
    checkout_session = Struct.new(:customer, :subscription).new("cus_test123", "sub_test123")

    tenant = SignupProvisioning.call(application: application, checkout_session: checkout_session)

    assert tenant.construction?
    assert application.reload.completed?
  end

  test "provisions a general tenant by default" do
    application = SignupApplication.create!(
      company_name: "テスト商店", contact_name: "佐藤", email: "sato@example.co.jp",
      agreed_to_terms: true
    )
    checkout_session = Struct.new(:customer, :subscription).new("cus_test456", "sub_test456")

    tenant = SignupProvisioning.call(application: application, checkout_session: checkout_session)

    assert_equal "general", tenant.edition
  end
end

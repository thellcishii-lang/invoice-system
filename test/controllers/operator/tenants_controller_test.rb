require "test_helper"

class Operator::TenantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    OperatorAccount.create!(email: "op@example.co.jp", password: "password123")
    @tenant = Tenant.create!(name: "スイッチ商事", billing_status: "active")
  end

  def sign_in_operator
    post operator_session_path, params: { email: "op@example.co.jp", password: "password123" }
  end

  test "operator can switch html mail on and off" do
    sign_in_operator
    assert_not @tenant.html_mail_enabled?

    patch operator_tenant_path(@tenant), params: { tenant: { html_mail_enabled: true } }
    assert_redirected_to operator_root_path
    assert @tenant.reload.html_mail_enabled?

    patch operator_tenant_path(@tenant), params: { tenant: { html_mail_enabled: false } }
    assert_redirected_to operator_root_path
    assert_not @tenant.reload.html_mail_enabled?
  end

  test "switching requires operator login" do
    patch operator_tenant_path(@tenant), params: { tenant: { html_mail_enabled: true } }

    assert_redirected_to new_operator_session_path
    assert_not @tenant.reload.html_mail_enabled?
  end
end

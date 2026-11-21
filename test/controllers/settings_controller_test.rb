require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when unauthenticated" do
    get setting_path

    assert_redirected_to new_session_path
  end

  test "shows own tenant settings when signed in" do
    sign_in_as(users(:one))

    get setting_path

    assert_response :success
    assert_match ERB::Util.html_escape(tenants(:one).name), response.body
    assert_no_match ERB::Util.html_escape(tenants(:two).name), response.body
  end

  test "updates own tenant settings only" do
    sign_in_as(users(:one))

    patch setting_path, params: { tenant: {
      name: "変更後の会社名",
      invoice_registration_number: "T9999999999999",
      document_number_prefix: "INV-",
      tax_rounding: "ceil",
      tax_display: "inclusive"
    } }

    assert_redirected_to setting_path

    tenant = tenants(:one).reload
    assert_equal "変更後の会社名", tenant.name
    assert_equal "T9999999999999", tenant.invoice_registration_number
    assert_equal "INV-", tenant.document_number_prefix
    assert_equal "ceil", tenant.tax_rounding
    assert_equal "inclusive", tenant.tax_display

    other = tenants(:two).reload
    assert_equal "テスト商事株式会社", other.name
    assert_equal "TS-", other.document_number_prefix
  end
end

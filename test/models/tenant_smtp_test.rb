require "test_helper"

class TenantSmtpTest < ActiveSupport::TestCase
  test "password is stored encrypted and read back decrypted" do
    tenant = tenants(:one)
    tenant.update!(smtp_host: "smtp.example.co.jp", smtp_username: "user@example.co.jp",
                   smtp_from_address: "user@example.co.jp", smtp_password: "secret-password")

    assert_equal "secret-password", tenant.smtp_password
    assert_not_includes tenant.reload.smtp_password_ciphertext, "secret-password"
    assert tenant.smtp_configured?
  end

  test "port 465 uses SSL, other ports use STARTTLS" do
    tenant = tenants(:one)
    tenant.assign_attributes(smtp_host: "smtp.zoho.jp", smtp_port: 465,
                             smtp_username: "u", smtp_from_address: "u@example.co.jp")
    tenant.smtp_password = "pw"
    assert_equal true, tenant.smtp_settings[:ssl]

    tenant.smtp_port = 587
    assert_equal true, tenant.smtp_settings[:enable_starttls_auto]
  end

  test "not configured until all fields are present" do
    tenant = tenants(:one)
    assert_not tenant.smtp_configured?

    tenant.smtp_host = "smtp.example.co.jp"
    assert_not tenant.smtp_configured?
  end
end

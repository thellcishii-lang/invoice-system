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

  test "saves the envelope print settings" do
    sign_in_as(users(:one))

    patch setting_path, params: { tenant: {
      envelope_size: "chou3", envelope_direction: "vertical",
      envelope_sender: "0", envelope_logo: "1"
    } }

    assert_redirected_to setting_path
    tenant = tenants(:one).reload
    assert_equal "chou3", tenant.envelope_size
    assert_equal "vertical", tenant.envelope_direction
    assert_equal false, tenant.envelope_sender
    assert_equal true, tenant.envelope_logo
  end

  test "saves bank account fields and a seal image" do
    sign_in_as(users(:one))

    patch setting_path, params: { tenant: {
      name: tenants(:one).name,
      bank_name: "〇〇銀行", bank_branch: "〇〇支店", bank_account_type: "普通",
      bank_account_number: "1234567", bank_account_holder: "テストカブシキガイシャ",
      seal_image: fixture_file_upload("seal.png", "image/png")
    } }

    assert_redirected_to setting_path

    tenant = tenants(:one).reload
    assert_equal "〇〇銀行", tenant.bank_name
    assert_equal "1234567", tenant.bank_account_number
    assert_equal "〇〇銀行 〇〇支店 普通 1234567\n口座名義：テストカブシキガイシャ", tenant.bank_details_text
    assert tenant.seal_image?
  end

  test "saves a logo image with its placement" do
    sign_in_as(users(:one))

    patch setting_path, params: { tenant: {
      name: tenants(:one).name,
      logo_image: fixture_file_upload("seal.png", "image/png"),
      logo_placement: "bottom", logo_alignment: "center"
    } }

    assert_redirected_to setting_path

    tenant = tenants(:one).reload
    assert tenant.logo_image?
    assert_equal "bottom", tenant.logo_placement
    assert_equal "center", tenant.logo_alignment
  end

  test "removes the seal image when asked" do
    sign_in_as(users(:one))
    tenants(:one).attach_seal(ActionDispatch::Http::UploadedFile.new(
      tempfile: File.new(Rails.root.join("test/fixtures/files/seal.png")),
      filename: "seal.png", type: "image/png"
    ))

    patch setting_path, params: { tenant: { name: tenants(:one).name, remove_seal: "1" } }

    assert_redirected_to setting_path
    assert_not tenants(:one).reload.seal_image?
  end
end

class SettingsEditionTest < ActionDispatch::IntegrationTest
  test "switches the tenant edition" do
    sign_in_as(users(:one))

    patch setting_path, params: { tenant: { edition: "construction" } }

    assert_redirected_to setting_path
    assert tenants(:one).reload.construction?
  end
end

class SettingsSmtpTest < ActionDispatch::IntegrationTest
  test "saves SMTP settings with an encrypted password and keeps it when left blank" do
    sign_in_as(users(:one))

    patch setting_path, params: { tenant: {
      smtp_host: "smtp.zoho.jp", smtp_port: 465, smtp_username: "me@mycompany.co.jp",
      smtp_from_address: "me@mycompany.co.jp", smtp_password: "my-secret"
    } }
    tenant = tenants(:one).reload
    assert tenant.smtp_configured?
    assert_equal "my-secret", tenant.smtp_password
    assert_not_includes tenant.smtp_password_ciphertext, "my-secret"

    patch setting_path, params: { tenant: { smtp_host: "smtp.zoho.jp", smtp_password: "" } }
    assert_equal "my-secret", tenants(:one).reload.smtp_password, "空欄なら保持される"
  end

  test "clears SMTP settings" do
    sign_in_as(users(:one))
    tenants(:one).update!(smtp_host: "smtp.zoho.jp", smtp_username: "u",
                           smtp_from_address: "u@example.co.jp", smtp_password: "pw")

    patch setting_path, params: { tenant: { clear_smtp: "1" } }

    assert_not tenants(:one).reload.smtp_configured?
  end

  test "test_smtp sends with saved settings" do
    sign_in_as(users(:one))
    tenants(:one).update!(smtp_host: "smtp.zoho.jp", smtp_username: "u",
                           smtp_from_address: "u@example.co.jp", smtp_password: "pw")

    assert_emails 1 do
      post test_smtp_setting_path
    end
    assert_redirected_to setting_path
  end
end

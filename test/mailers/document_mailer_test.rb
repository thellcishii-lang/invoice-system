require "test_helper"

class DocumentMailerTest < ActionMailer::TestCase
  test "document_email includes kind, number, total, due date and the public link" do
    document = documents(:invoice_one)
    token = document.public_link_token
    mail = DocumentMailer.document_email(document: document, recipient_email: "billing@example.co.jp", token: token)

    assert_equal [ "billing@example.co.jp" ], mail.to
    assert_equal [ "no-reply@example.com" ], mail.from
    assert_match "請求書", mail.subject
    assert_match document.number, mail.subject

    # メールはテキストのみ（HTMLパートは付けない）
    assert_not mail.multipart?
    assert_nil mail.html_part

    body = mail.body.decoded
    assert_match document.client.name, body
    assert_match document.number, body
    assert_match "48,100円", body
    assert_match "2026年11月30日", body
    assert_match "http://example.com/public/documents/#{token}", body
  end

  test "document_email omits the due date for non-invoice documents" do
    document = documents(:estimate_one)
    mail = DocumentMailer.document_email(document: document, recipient_email: "a@example.co.jp", token: document.public_link_token)

    assert_match "見積書", mail.subject
    assert_no_match "お支払期限", mail.body.decoded
  end
end

class DocumentMailerReplyToTest < ActionMailer::TestCase
  test "document_email replies go to the tenant, not the operator" do
    document = documents(:invoice_one)
    token = Rails.application.message_verifier("document/public_view").generate(document.id)
    mail = DocumentMailer.document_email(document: document, recipient_email: "billing@example.co.jp", token: token)
    assert_equal [ document.tenant.email ], mail.reply_to
  end
end

class DocumentMailerTenantSmtpTest < ActionMailer::TestCase
  test "uses the tenant's own SMTP and address when configured" do
    tenant = tenants(:one)
    tenant.update!(smtp_host: "smtp.tenant.example.co.jp", smtp_port: 587,
                   smtp_username: "billing@tenant.example.co.jp",
                   smtp_from_address: "billing@tenant.example.co.jp", smtp_password: "pw1234")
    document = documents(:invoice_one)
    token = Rails.application.message_verifier("document/public_view").generate(document.id)

    mail = DocumentMailer.document_email(document: document, recipient_email: "c@example.co.jp", token: token)

    assert_equal [ "billing@tenant.example.co.jp" ], mail.from
    assert_equal "smtp.tenant.example.co.jp", mail.delivery_method.settings[:address]
    assert_equal "billing@tenant.example.co.jp", mail.delivery_method.settings[:user_name]
  end
end

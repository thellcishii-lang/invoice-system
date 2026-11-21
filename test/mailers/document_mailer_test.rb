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

    body = mail.text_part.body.decoded
    assert_match document.client.name, body
    assert_match document.number, body
    assert_match "48,100円", body
    assert_match "2026年11月30日", body
    assert_match "http://example.com/public/documents/#{token}", body

    html = mail.html_part.body.decoded
    assert_match "48,100円", html
    assert_match "/public/documents/#{token}", html
  end

  test "document_email omits the due date for non-invoice documents" do
    document = documents(:estimate_one)
    mail = DocumentMailer.document_email(document: document, recipient_email: "a@example.co.jp", token: document.public_link_token)

    assert_match "見積書", mail.subject
    assert_no_match "お支払期限", mail.text_part.body.decoded
  end
end

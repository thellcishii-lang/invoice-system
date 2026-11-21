require "test_helper"

class PublicDocumentsControllerTest < ActionDispatch::IntegrationTest
  test "opens the print view with a valid token without login" do
    document = documents(:invoice_one)

    get public_document_path(document.public_link_token)

    assert_response :success
    assert_match "請求書", response.body
    assert_match document.number, response.body
    assert_match ERB::Util.html_escape(document.client.name), response.body
    assert_match "48,100円", response.body
    # 公開画面には管理画面への導線を出さない
    assert_no_match "帳票の詳細に戻る", response.body
  end

  test "rejects a tampered token" do
    token = documents(:invoice_one).public_link_token
    tampered = token.dup
    tampered[10] = tampered[10] == "A" ? "B" : "A"

    get public_document_path(tampered)

    assert_response :not_found
  end

  test "rejects an expired token" do
    expired = documents(:invoice_one).signed_id(purpose: Document::PUBLIC_LINK_PURPOSE, expires_in: -1.day)

    get public_document_path(expired)

    assert_response :not_found
  end

  test "rejects a token signed for another purpose" do
    other_purpose = documents(:invoice_one).signed_id(purpose: "something_else", expires_in: 30.days)

    get public_document_path(other_purpose)

    assert_response :not_found
  end
end

require "test_helper"

class HtmlMailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = tenants(:one)
    sign_in_as(users(:one))
  end

  test "yearly active tenant sees the composer" do
    @tenant.update!(billing_interval: "yearly", billing_status: "active")

    get html_mail_path

    assert_response :success
    assert_match "宛先", response.body
    assert_match "送信する", response.body
  end

  test "yearly active tenant can send an html mail with tenant branding" do
    @tenant.update!(billing_interval: "yearly", billing_status: "active")

    assert_emails 1 do
      post html_mail_path, params: { html_mail: {
        recipient_email: "dest@example.co.jp", subject: "ご挨拶",
        body: "いつもお世話になっております。"
      } }
    end
    assert_redirected_to html_mail_path

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "dest@example.co.jp" ], mail.to
    assert_equal "ご挨拶", mail.subject
    assert_match "いつもお世話になっております", mail.html_part.body.decoded
    assert_match ERB::Util.html_escape(@tenant.name), mail.html_part.body.decoded
    assert_match "いつもお世話になっております", mail.text_part.body.decoded
  end

  test "monthly tenant sees the yearly-plan guidance and cannot send" do
    @tenant.update!(billing_interval: "monthly", billing_status: "active")

    get html_mail_path
    assert_response :success
    assert_match "年払いプランに含まれる機能です", response.body

    assert_no_emails do
      post html_mail_path, params: { html_mail: {
        recipient_email: "dest@example.co.jp", subject: "ご挨拶", body: "本文"
      } }
    end
  end

  test "yearly but cancelled tenant is not html mail enabled" do
    @tenant.update!(billing_interval: "yearly", billing_status: "cancelled")

    assert_not @tenant.html_mail_enabled?
    # 解約済みテナントは課金ゲートでログイン画面へ戻される（既存の挙動）
    get html_mail_path
    assert_redirected_to new_session_path
  end
end

require "test_helper"

class HtmlMailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = tenants(:one)
    sign_in_as(users(:one))
  end

  test "tenant with html mail switched on sees the composer and the sidebar link" do
    @tenant.update!(html_mail_enabled: true)

    get html_mail_path
    assert_response :success
    assert_match "宛先", response.body
    assert_match "送信する", response.body

    get root_path
    assert_match "HTMLメール", response.body
  end

  test "tenant with html mail switched on can send an html mail with tenant branding" do
    @tenant.update!(html_mail_enabled: true)

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

  test "tenant with html mail off sees nothing of the feature" do
    assert_not @tenant.html_mail_enabled?

    get root_path
    assert_no_match "HTMLメール", response.body

    get html_mail_path
    assert_redirected_to root_path

    assert_no_emails do
      post html_mail_path, params: { html_mail: {
        recipient_email: "dest@example.co.jp", subject: "ご挨拶", body: "本文"
      } }
    end
    assert_redirected_to root_path
  end
end

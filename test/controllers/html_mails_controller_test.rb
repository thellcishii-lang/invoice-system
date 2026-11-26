require "test_helper"
require "socket"
require "json"

class HtmlMailsControllerTest < ActionDispatch::IntegrationTest
  # 連動APIのスタブHTTPサーバー。リクエストを captured に記録して JSON を返す。
  def with_stub_api(response_body:, status: 200)
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    captured = {}
    thread = Thread.new do
      socket = server.accept
      request_line = socket.gets
      headers = {}
      while (line = socket.gets) && line != "\r\n"
        k, v = line.split(": ", 2)
        headers[k.to_s.downcase] = v.to_s.strip
      end
      length = headers["content-length"].to_i
      captured[:body] = length.positive? ? socket.read(length) : ""
      captured[:authorization] = headers["authorization"]
      captured[:path] = request_line.to_s.split(" ")[1]
      socket.write "HTTP/1.1 #{status} OK\r\nContent-Type: application/json\r\nContent-Length: #{response_body.bytesize}\r\nConnection: close\r\n\r\n#{response_body}"
      socket.close
    end
    old = ENV["HTML_MAIL_API_URL"]
    ENV["HTML_MAIL_API_URL"] = "http://127.0.0.1:#{port}"
    yield captured
  ensure
    ENV["HTML_MAIL_API_URL"] = old
    thread&.join(5)
    server&.close
  end

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

  test "linked tenant sends through the html mail api instead of local mail" do
    @tenant.update!(html_mail_enabled: true, html_mail_link_key: "hm_test_key")
    captured = nil
    assert_no_emails do
      with_stub_api(response_body: { ok: true }.to_json) do |cap|
        captured = cap
        post html_mail_path, params: { html_mail: {
          recipient_email: "dest@example.co.jp", subject: "連動テスト", body: "本文です"
        } }
      end
    end
    assert_redirected_to html_mail_path
    assert_equal "/api/send", captured[:path]
    assert_equal "Bearer hm_test_key", captured[:authorization]
    sent = JSON.parse(captured[:body])
    assert_equal({ "to" => "dest@example.co.jp", "subject" => "連動テスト", "body" => "本文です" }, sent)
  end

  test "linked tenant sees the api error when delivery fails" do
    @tenant.update!(html_mail_enabled: true, html_mail_link_key: "hm_test_key")
    with_stub_api(response_body: { ok: false, error: "連動キーが正しくありません" }.to_json, status: 401) do
      post html_mail_path, params: { html_mail: {
        recipient_email: "dest@example.co.jp", subject: "件名", body: "本文"
      } }
    end
    assert_response :unprocessable_entity
    assert_match "連動キーが正しくありません", response.body
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

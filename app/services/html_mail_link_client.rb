require "net/http"
require "json"

# HTMLメール（単体アプリ）の連動APIクライアント。
# 連動キーで認証し、接続確認と送信だけを行う（受信や様式の管理はあちら側）。
class HtmlMailLinkClient
  Result = Struct.new(:ok, :error, :account_name, keyword_init: true) do
    def ok?
      !!ok
    end
  end

  def initialize(tenant)
    @tenant = tenant
  end

  # 疎通確認（メールは送らない）
  def check
    response = request(Net::HTTP::Get.new(uri("/api/link/check")))
    body = parse(response)
    if response.is_a?(Net::HTTPSuccess) && body["ok"]
      Result.new(ok: true, account_name: body["account"])
    else
      Result.new(ok: false, error: body["error"] || "接続できませんでした（HTTP #{response.code}）")
    end
  rescue StandardError => e
    Result.new(ok: false, error: "接続できませんでした：#{e.message}")
  end

  # 連動先経由で送信する
  def deliver(to:, subject:, body:)
    http_request = Net::HTTP::Post.new(uri("/api/send"))
    http_request["Content-Type"] = "application/json"
    http_request.body = JSON.generate(to: to, subject: subject, body: body)
    response = request(http_request)
    parsed = parse(response)
    if response.is_a?(Net::HTTPSuccess) && parsed["ok"]
      Result.new(ok: true)
    else
      Result.new(ok: false, error: parsed["error"] || "送信に失敗しました（HTTP #{response.code}）")
    end
  rescue StandardError => e
    Result.new(ok: false, error: "送信に失敗しました：#{e.message}")
  end

  private

  def base_url
    ENV.fetch("HTML_MAIL_API_URL", "https://admin-mail-green.vercel.app").sub(%r{/+\z}, "")
  end

  def uri(path)
    URI("#{base_url}#{path}")
  end

  def request(http_request)
    http_request["Authorization"] = "Bearer #{@tenant.html_mail_link_key}"
    target = http_request.uri
    Net::HTTP.start(target.host, target.port, use_ssl: target.scheme == "https", open_timeout: 10, read_timeout: 30) do |http|
      http.request(http_request)
    end
  end

  def parse(response)
    JSON.parse(response.body.to_s)
  rescue JSON::ParserError
    {}
  end
end

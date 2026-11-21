class ApplicationMailer < ActionMailer::Base
  # 送信元は運用者の標準メール（Zoho）のアドレス。環境変数が無い環境では
  # プレースホルダを使う。
  default from: -> { ENV["INFOMAIL_USER"].presence || "no-reply@example.com" }
  layout "mailer"
end

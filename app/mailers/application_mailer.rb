class ApplicationMailer < ActionMailer::Base
  # 送信元は運用者の標準メール（Zoho）のアドレス。環境変数が無い環境では
  # プレースホルダを使う。
  default from: -> { ENV["INFOMAIL_USER"].presence || "no-reply@example.com" }
  layout "mailer"

  private
    # テナントが自分の SMTP を設定していれば、そのメールにその設定を適用する。
    def apply_tenant_smtp(message, tenant)
      return unless tenant&.smtp_configured?

      message.delivery_method.settings.merge!(tenant.smtp_settings)
    end
end

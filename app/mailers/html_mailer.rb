class HtmlMailer < ApplicationMailer
  # 年払い特典のHTMLメール: 帳票と関係ない自由な業務メールを、テナントの
  # ブランド（会社名・帳票色）付きのHTMLで送る。送信経路は帳票メールと同じで、
  # テナント自身のSMTP設定があればそのアドレスから、なければ運営のZoho
  # アドレスからReply-To付きで送る。
  def business_email(tenant:, recipient_email:, subject:, body:)
    @tenant = tenant
    @body = body

    mail_args = { to: recipient_email, reply_to: tenant.email.presence, subject: subject }
    mail_args[:from] = tenant.smtp_from_address if tenant.smtp_configured?
    message = mail(**mail_args)
    apply_tenant_smtp(message, tenant)
    message
  end
end

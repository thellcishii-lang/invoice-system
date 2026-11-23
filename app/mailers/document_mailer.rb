class DocumentMailer < ApplicationMailer
  # 帳票を取引先へ送るメール。本文には公開リンク（署名付き・期限付き）を載せ、
  # 受け取った側はログインなしで帳票の印刷画面を確認できる。
  def document_email(document:, recipient_email:, token:, send_template: nil)
    @document = document
    @public_url = public_document_url(token)

    subject = "#{document.kind_label}（#{document.number}）をお送りします"
    if send_template.present?
      @custom_body = send_template.render_body(document)
      rendered_subject = send_template.render_subject(document)
      subject = rendered_subject if rendered_subject.present?
    end

    # 差出人は運営の Zoho アドレス（全テナント共通）。返信はテナントに届くよう
    # Reply-To にテナントのメールアドレスを入れる。
    mail to: recipient_email, reply_to: document.tenant.email.presence, subject: subject
  end
end

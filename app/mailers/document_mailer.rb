class DocumentMailer < ApplicationMailer
  # 帳票を取引先へ送るメール。本文には公開リンク（署名付き・期限付き）を載せ、
  # 受け取った側はログインなしで帳票の印刷画面を確認できる。
  def document_email(document:, recipient_email:, token:)
    @document = document
    @public_url = public_document_url(token)

    mail to: recipient_email,
         subject: "#{document.kind_label}（#{document.number}）をお送りします"
  end
end

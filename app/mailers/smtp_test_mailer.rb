class SmtpTestMailer < ApplicationMailer
# 事業者マスターの「テスト送信」用。テナント自身の SMTP 設定で送る。
def test_email(tenant)
message = mail(
to: tenant.email,
from: tenant.smtp_from_address,
subject: "メール送信設定の確認",
body: "このメールは、見積・請求書システムのメール送信（SMTP）設定のテスト送信です。\n届いていれば、帳票メールはこのアドレスから送信されます。"
)
apply_tenant_smtp(message, tenant)
message
end
end

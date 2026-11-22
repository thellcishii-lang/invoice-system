class SignupMailer < ApplicationMailer
# 申込完了時の招待メール。パスワード設定リンク（72時間有効）のみを載せ、
# パスワード自体は送らない。
def invite(user:, token:)
@user = user
@password_setup_url = password_setup_url(token)

mail to: user.email_address,
subject: "お申し込みありがとうございます（パスワード設定のご案内）"
end
end

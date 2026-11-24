class MemberMailer < ApplicationMailer
# メンバー招待メール。パスワード設定リンク（72時間有効）のみを載せ、
# パスワード自体は送らない。本人が設定して個別にログインする。
def invite(user:, token:)
@user = user
@password_setup_url = password_setup_url(token)

mail to: user.email_address,
subject: "見積・請求書システムへのご招待"
end
end

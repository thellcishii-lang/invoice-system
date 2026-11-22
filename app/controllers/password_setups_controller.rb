# 招待メールのリンクから最初のパスワードを設定する画面（ログイン不要）。
# トークンは署名付きIDで72時間有効。
class PasswordSetupsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token

  def edit
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      @user.sessions.destroy_all
      redirect_to new_session_path, notice: "パスワードを設定しました。ログインしてください。"
    else
      redirect_to password_setup_path(params[:token]), alert: "パスワードが一致しないか、条件を満たしていません。"
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_setup_token(params[:token])
      return if @user.present?

      redirect_to new_session_path, alert: "パスワード設定リンクが無効か、期限切れです。"
    end
end

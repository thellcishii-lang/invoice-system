class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "しばらくしてからもう一度お試しください。" }

  def new
  end

  def create
    user = User.authenticate_by(params.permit(:email_address, :password))

    if user && !user.disabled? && user.tenant.billing_blocked?
      redirect_to new_session_path, alert: user.tenant.billing_blocked_message
    elsif user && !user.disabled?
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "メールアドレスまたはパスワードが違います。"
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end

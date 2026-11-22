# 公開申込フロー（ログイン不要）: 入力 → 確認 → Stripe Checkout → 完了。
# テナントと最初のユーザーは決済完了の Webhook で発行される。
class SignupsController < ApplicationController
  allow_unauthenticated_access

  def new
    @application = SignupApplication.new
    @stripe_configured = StripeClient.checkout_configured?
  end

  def confirm
    @application = SignupApplication.new(signup_params)
    @stripe_configured = StripeClient.checkout_configured?

    if @application.valid?
      render :confirm
    else
      render :new, status: :unprocessable_entity
    end
  end

  def create
    @application = SignupApplication.new(signup_params)

    unless @application.valid?
      @stripe_configured = StripeClient.checkout_configured?
      return render :new, status: :unprocessable_entity
    end

    unless StripeClient.checkout_configured?
      return redirect_to new_signup_path, alert: "現在お申し込みを受け付けておりません。"
    end

    @application.save!
    checkout_session = StripeClient.create_checkout_session(
      application: @application,
      success_url: complete_signups_url,
      cancel_url: new_signup_url
    )
    @application.update!(stripe_checkout_session_id: checkout_session.id)
    redirect_to checkout_session.url, allow_other_host: true
  rescue StripeClient::NotConfiguredError, Stripe::StripeError
    redirect_to new_signup_path, alert: "決済の準備に失敗しました。しばらくしてからもう一度お試しください。"
  end

  def complete
  end

  private
    def signup_params
      params.expect(signup_application: [ :company_name, :contact_name, :email, :agreed_to_terms ])
    end
end

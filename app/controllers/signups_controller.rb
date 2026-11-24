# 公開申込フロー（ログイン不要）: 入力 → 確認 → Stripe Checkout → 完了。
# テナントと最初のユーザーは決済完了の Webhook で発行される。
class SignupsController < ApplicationController
  allow_unauthenticated_access

  def new
    # 製品ごとに申込入口を分ける（一般 / 建築）。?edition=construction で建築版の申込になる。
    edition = Tenant::EDITIONS.include?(params[:edition]) ? params[:edition] : "general"
    @application = SignupApplication.new(edition: edition)
    @stripe_configured = StripeClient.checkout_configured?(edition: edition)
  end

  # 入力の検証だけを行い、内容はセッションに入れて確認画面へリダイレクトする。
  # Turbo はフォーム応答にリダイレクトを要求し、200で直接描画すると
  # ブラウザの画面遷移が止まる（代理店管理システムで踏んだ不具合と同じ）。
  def confirm
    @application = SignupApplication.new(signup_params)

    if @application.valid?
      session[:signup_attributes] = signup_params.to_h
      redirect_to confirm_signups_path
    else
      @stripe_configured = StripeClient.checkout_configured?(edition: @application.edition, interval: @application.billing_interval)
      render :new, status: :unprocessable_entity
    end
  end

  # 確認画面の表示（GET）。入力内容はセッションから復元する。
  def confirmation
    attributes = session[:signup_attributes]
    return redirect_to new_signup_path, alert: "お申し込み内容の有効期限が切れました。もう一度入力してください。" if attributes.blank?

    @application = SignupApplication.new(attributes)
    render :confirm
  end

  def create
    @application = SignupApplication.new(session[:signup_attributes].presence || signup_params)

    unless @application.valid?
      @stripe_configured = StripeClient.checkout_configured?(edition: @application.edition, interval: @application.billing_interval)
      return render :new, status: :unprocessable_entity
    end

    unless StripeClient.checkout_configured?(edition: @application.edition, interval: @application.billing_interval)
      return redirect_to new_signup_path(edition: @application.edition), alert: "現在お申し込みを受け付けておりません。"
    end

    @application.save!
    session.delete(:signup_attributes)
    checkout_session = StripeClient.create_checkout_session(
      application: @application,
      success_url: complete_signups_url,
      cancel_url: new_signup_url(edition: @application.edition)
    )
    @application.update!(stripe_checkout_session_id: checkout_session.id)
    redirect_to checkout_session.url, allow_other_host: true
  rescue StripeClient::NotConfiguredError, Stripe::StripeError
    redirect_to new_signup_path(edition: @application.edition), alert: "決済の準備に失敗しました。しばらくしてからもう一度お試しください。"
  end

  def complete
  end

  private
    def signup_params
      params.expect(signup_application: [ :company_name, :contact_name, :email, :agreed_to_terms, :edition, :billing_interval ])
    end
end

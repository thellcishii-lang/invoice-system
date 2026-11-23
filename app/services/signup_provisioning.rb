# Stripe Checkout 完了時に、申込からテナントと最初のログインユーザーを
# 発行する。招待メールにはパスワード設定リンク（72時間有効）だけを載せ、
# パスワード自体は送らない。同じ Checkout Session の再送に対して冪等。
class SignupProvisioning
  def self.call(application:, checkout_session:)
    new(application: application, checkout_session: checkout_session).call
  end

  def initialize(application:, checkout_session:)
    @application = application
    @checkout_session = checkout_session
  end

  # 発行したテナントを返す。発行済みなら既存のテナントを返す。
  def call
    return @application.tenant if @application.completed? && @application.tenant.present?

    tenant = nil
    user = nil
    @application.transaction do
      tenant = Tenant.create!(
        name: @application.company_name,
        email: @application.email,
        edition: @application.edition,
        billing_status: :active,
        stripe_customer_id: @checkout_session.customer,
        stripe_subscription_id: @checkout_session.subscription
      )
      # 仮パスワードで作成し、本人が招待リンクから設定し直す
      user = tenant.users.create!(
        name: @application.contact_name,
        email_address: @application.email,
        password: SecureRandom.hex(24),
        password_confirmation: nil
      )
      @application.update!(status: :completed, tenant: tenant)
    end

    SignupMailer.invite(user: user, token: user.password_setup_token).deliver_now
    tenant
  end
end

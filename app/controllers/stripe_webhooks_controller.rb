# Stripe からの Webhook 受信。署名検証を通ったイベントだけを処理する。
# checkout.session.completed でテナント発行、以降は課金状態の遷移のみ。
class StripeWebhooksController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection

  def create
    event = StripeClient.construct_event(request.raw_post, request.headers["Stripe-Signature"])

    case event.type
    when "checkout.session.completed"
      handle_checkout_completed(event.data.object)
    when "invoice.paid"
      handle_invoice_paid(event.data.object)
    when "invoice.payment_failed"
      handle_invoice_payment_failed(event.data.object)
    when "customer.subscription.deleted"
      handle_subscription_deleted(event.data.object)
    end

    head :ok
  rescue Stripe::SignatureVerificationError, JSON::ParserError
    head :bad_request
  end

  private
    def handle_checkout_completed(session)
      application = SignupApplication.find_by(stripe_checkout_session_id: session.id)
      return if application.blank?

      SignupProvisioning.call(application: application, checkout_session: session)
    end

    def handle_invoice_paid(invoice)
      tenant = tenant_for_customer(invoice.customer)
      return if tenant.blank? || tenant.billing_cancelled?

      tenant.update!(billing_status: :active)
      if invoice.subscription.present? && tenant.stripe_subscription_id != invoice.subscription
        tenant.update!(stripe_subscription_id: invoice.subscription)
      end
    end

    def handle_invoice_payment_failed(invoice)
      tenant = tenant_for_customer(invoice.customer)
      return if tenant.blank? || tenant.billing_cancelled?

      tenant.update!(billing_status: :suspended)
    end

    def handle_subscription_deleted(subscription)
      tenant = tenant_for_customer(subscription.customer)
      return if tenant.blank?

      attributes = { billing_status: :cancelled }
      attributes[:contract_ended_at] = Time.current if tenant.contract_ended_at.blank?
      tenant.update!(attributes)
    end

    def tenant_for_customer(customer_id)
      return if customer_id.blank?

      Tenant.find_by(stripe_customer_id: customer_id)
    end
end

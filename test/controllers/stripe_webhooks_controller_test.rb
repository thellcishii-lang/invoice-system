require "test_helper"

class StripeWebhooksControllerTest < ActionDispatch::IntegrationTest
  WEBHOOK_SECRET = "whsec_test_secret"

  setup do
    @saved_secret = ENV["STRIPE_WEBHOOK_SECRET"]
    ENV["STRIPE_WEBHOOK_SECRET"] = WEBHOOK_SECRET
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    ENV["STRIPE_WEBHOOK_SECRET"] = @saved_secret
  end

  test "checkout.session.completed issues a tenant and first user and sends an invite" do
    application = create_application

    assert_difference "Tenant.count", 1 do
      assert_difference "User.count", 1 do
        post_event(checkout_completed_event(application))
      end
    end
    assert_response :success

    application.reload
    assert application.completed?
    tenant = application.tenant
    assert_equal "申込テスト株式会社", tenant.name
    assert tenant.billing_active?
    assert_equal "cus_test_123", tenant.stripe_customer_id
    assert_equal "sub_test_123", tenant.stripe_subscription_id
    assert_equal 100, tenant.monthly_invoice_limit

    user = tenant.users.sole
    assert_equal "申込太郎", user.name
    assert_equal "apply@example.co.jp", user.email_address

    invite = ActionMailer::Base.deliveries.last
    assert_equal [ "apply@example.co.jp" ], invite.to
    assert_match "パスワード設定", invite.subject
    mail_body = invite.multipart? ? invite.parts.map { |part| part.body.to_s }.join : invite.body.to_s
    assert_match "/password_setup/", mail_body
  end

  test "checkout.session.completed is idempotent on redelivery" do
    application = create_application
    post_event(checkout_completed_event(application))

    assert_no_difference "Tenant.count" do
      assert_no_difference "User.count" do
        assert_no_difference "ActionMailer::Base.deliveries.size" do
          post_event(checkout_completed_event(application))
        end
      end
    end
    assert_response :success
  end

  test "invoice.paid reactivates a suspended tenant" do
    tenant = create_billing_tenant(billing_status: :suspended)

    post_event(type: "invoice.paid", object: { id: "in_1", customer: tenant.stripe_customer_id, subscription: "sub_test_123" })

    assert_response :success
    assert tenant.reload.billing_active?
  end

  test "invoice.payment_failed suspends an active tenant" do
    tenant = create_billing_tenant(billing_status: :active)

    post_event(type: "invoice.payment_failed", object: { id: "in_1", customer: tenant.stripe_customer_id, subscription: "sub_test_123" })

    assert_response :success
    assert tenant.reload.billing_suspended?
  end

  test "customer.subscription.deleted cancels the tenant and records the contract end" do
    tenant = create_billing_tenant(billing_status: :active)
    assert_nil tenant.contract_ended_at

    post_event(type: "customer.subscription.deleted", object: { id: "sub_test_123", customer: tenant.stripe_customer_id })

    assert_response :success
    tenant.reload
    assert tenant.billing_cancelled?
    assert_in_delta Time.current.to_i, tenant.contract_ended_at.to_i, 5
  end

  test "rejects a request with an invalid signature" do
    payload = { id: "evt_1", type: "invoice.paid", data: { object: { customer: "cus_x" } } }.to_json

    post "/stripe/webhooks", params: payload,
         headers: { "CONTENT_TYPE" => "application/json", "Stripe-Signature" => "t=1,v1=invalid" }

    assert_response :bad_request
  end

  test "unknown customer events are accepted without changes" do
    post_event(type: "invoice.paid", object: { id: "in_1", customer: "cus_unknown", subscription: "sub_x" })

    assert_response :success
  end

  private
    def create_application
      SignupApplication.create!(
        company_name: "申込テスト株式会社", contact_name: "申込太郎",
        email: "apply@example.co.jp", agreed_to_terms: true,
        stripe_checkout_session_id: "cs_test_123"
      )
    end

    def create_billing_tenant(billing_status:)
      Tenant.create!(
        name: "課金テスト株式会社", billing_status: billing_status,
        stripe_customer_id: "cus_test_#{SecureRandom.hex(4)}", stripe_subscription_id: "sub_test_123"
      )
    end

    def checkout_completed_event(application)
      {
        type: "checkout.session.completed",
        object: {
          id: application.stripe_checkout_session_id,
          customer: "cus_test_123",
          subscription: "sub_test_123"
        }
      }
    end

    # Stripe の署名（t=...,v1=...）を付けた Webhook を送る
    def post_event(event)
      payload = { id: "evt_#{SecureRandom.hex(4)}", type: event[:type], data: { object: event[:object] } }.to_json
      timestamp = Time.current.to_i
      signature = OpenSSL::HMAC.hexdigest("SHA256", WEBHOOK_SECRET, "#{timestamp}.#{payload}")

      post "/stripe/webhooks", params: payload,
           headers: { "CONTENT_TYPE" => "application/json",
                      "Stripe-Signature" => "t=#{timestamp},v1=#{signature}" }
    end
end

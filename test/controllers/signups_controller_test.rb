require "test_helper"

class SignupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @params = {
      signup_application: {
        company_name: "申込テスト株式会社",
        contact_name: "申込太郎",
        email: "apply@example.co.jp",
        agreed_to_terms: "1"
      }
    }
    @saved_env = ENV.slice("STRIPE_SECRET_KEY", "STRIPE_PRICE_ID", "STRIPE_TAX_RATE_ID")
    ENV.delete("STRIPE_SECRET_KEY")
    ENV.delete("STRIPE_PRICE_ID")
    ENV.delete("STRIPE_TAX_RATE_ID")
  end

  teardown do
    ENV.update(@saved_env)
  end

  test "new renders the form without login" do
    get new_signup_path

    assert_response :success
    assert_select "h1", "新規お申し込み"
  end

  test "new shows a preparation notice when Stripe is not configured" do
    get new_signup_path

    assert_response :success
    assert_match "現在、準備中のためお申し込みを受け付けておりません", response.body
  end

  test "confirm redirects to the confirmation page, which renders the entered values" do
    post confirm_signups_path, params: @params

    assert_redirected_to confirm_signups_path

    get confirm_signups_path
    assert_response :success
    assert_match "申込テスト株式会社", response.body
    assert_match "申込太郎", response.body
    assert_match "apply@example.co.jp", response.body
    assert_match "お支払いへ進む", response.body
    assert_match 'data-turbo="false"', response.body
  end

  test "confirmation without input redirects back to the form" do
    get confirm_signups_path

    assert_redirected_to new_signup_path
  end

  test "confirm with invalid params re-renders the form" do
    post confirm_signups_path, params: {
      signup_application: { company_name: "", contact_name: "", email: "not-an-email", agreed_to_terms: "0" }
    }

    assert_response :unprocessable_entity
  end

  test "create redirects back with an alert when Stripe is not configured" do
    assert_no_difference "SignupApplication.count" do
      post signups_path, params: @params
    end

    assert_redirected_to new_signup_path(edition: "general")
    assert_equal "現在お申し込みを受け付けておりません。", flash[:alert]
  end

  test "create saves the application and redirects to Stripe Checkout when configured" do
    ENV["STRIPE_SECRET_KEY"] = "sk_test_dummy"
    ENV["STRIPE_PRICE_ID"] = "price_dummy"

    fake_session = Struct.new(:id, :url).new("cs_test_123", "https://checkout.stripe.com/pay/cs_test_123")
    with_stubbed_checkout(fake_session) do
      assert_difference "SignupApplication.count", 1 do
        post signups_path, params: @params
      end
    end

    application = SignupApplication.last
    assert_equal "cs_test_123", application.stripe_checkout_session_id
    assert application.pending?
    assert_redirected_to "https://checkout.stripe.com/pay/cs_test_123"
  end

  test "complete renders a thank-you page" do
    get complete_signups_path

    assert_response :success
    assert_match "お申し込みを受け付けました", response.body
  end

  private
    # StripeClient.create_checkout_session を差し替えて実行する（実APIは呼ばない）
    def with_stubbed_checkout(fake_session)
      original = StripeClient.method(:create_checkout_session)
      StripeClient.define_singleton_method(:create_checkout_session) do |application:, success_url:, cancel_url:|
        fake_session
      end
      yield
    ensure
      StripeClient.define_singleton_method(:create_checkout_session) { |**args| original.call(**args) }
    end
end

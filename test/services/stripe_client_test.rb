require "test_helper"

class StripeClientTest < ActiveSupport::TestCase
  setup do
    @saved_env = ENV.slice("STRIPE_SECRET_KEY", "STRIPE_PRICE_ID", "STRIPE_PRICE_ID_CONSTRUCTION", "STRIPE_PRICE_ID_YEARLY", "STRIPE_PRICE_ID_CONSTRUCTION_YEARLY")
    ENV["STRIPE_SECRET_KEY"] = "sk_test_dummy"
    ENV["STRIPE_PRICE_ID"] = "price_general"
    ENV.delete("STRIPE_PRICE_ID_CONSTRUCTION")
    ENV.delete("STRIPE_PRICE_ID_YEARLY")
    ENV.delete("STRIPE_PRICE_ID_CONSTRUCTION_YEARLY")
  end

  teardown do
    ENV.update(@saved_env)
    %w[STRIPE_SECRET_KEY STRIPE_PRICE_ID STRIPE_PRICE_ID_CONSTRUCTION STRIPE_PRICE_ID_YEARLY STRIPE_PRICE_ID_CONSTRUCTION_YEARLY].each do |key|
      ENV.delete(key) unless @saved_env.key?(key)
    end
  end

  test "price_id_for picks the price by edition, falling back to general for construction" do
    assert_equal "price_general", StripeClient.price_id_for("general")
    assert_equal "price_general", StripeClient.price_id_for("construction")

    ENV["STRIPE_PRICE_ID_CONSTRUCTION"] = "price_construction"
    assert_equal "price_construction", StripeClient.price_id_for("construction")
  end

  test "checkout_configured? is per edition" do
    assert StripeClient.checkout_configured?(edition: "general")
    assert StripeClient.checkout_configured?(edition: "construction")
  end

  test "price_id_for picks the yearly price by interval" do
    assert_nil StripeClient.price_id_for("general", "yearly")
    assert_not StripeClient.checkout_configured?(edition: "general", interval: "yearly")

    ENV["STRIPE_PRICE_ID_YEARLY"] = "price_yearly"
    assert_equal "price_yearly", StripeClient.price_id_for("general", "yearly")
    assert_equal "price_yearly", StripeClient.price_id_for("construction", "yearly")
    assert StripeClient.checkout_configured?(edition: "general", interval: "yearly")

    ENV["STRIPE_PRICE_ID_CONSTRUCTION_YEARLY"] = "price_construction_yearly"
    assert_equal "price_construction_yearly", StripeClient.price_id_for("construction", "yearly")
  end

  test "plan price follows the billing interval" do
    assert_equal 2500, SignupApplication.new(edition: "general", billing_interval: "monthly").plan_price_tax_excluded
    assert_equal 25_000, SignupApplication.new(edition: "general", billing_interval: "yearly").plan_price_tax_excluded
    assert_equal 25_000, SignupApplication.new(edition: "construction", billing_interval: "yearly").plan_price_tax_excluded
  end

  test "plan prices are decided per edition" do
    assert_equal 2500, SignupApplication.new(edition: "general").price_tax_excluded
    assert_equal 2500, SignupApplication.new(edition: "construction").price_tax_excluded
  end
end

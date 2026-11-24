# Stripe へのアクセスはすべてこのクラス経由にする（テストでは
# define_singleton_method で差し替えられるようにするため）。
# 価格ID・税率IDは環境変数から読む。金額はコードに書かない。
# 料金はエディションごとに価格IDを分ける（一般: STRIPE_PRICE_ID /
# 建築: STRIPE_PRICE_ID_CONSTRUCTION）。
class StripeClient
  class NotConfiguredError < StandardError; end

  class << self
    # エディションに対応する Stripe 価格ID
    def price_id_for(edition)
      edition.to_s == "construction" ? ENV["STRIPE_PRICE_ID_CONSTRUCTION"] : ENV["STRIPE_PRICE_ID"]
    end

    # 秘密鍵と、そのエディションの価格IDが揃っていれば申込受付可能
    def checkout_configured?(edition: "general")
      ENV["STRIPE_SECRET_KEY"].present? && price_id_for(edition).present?
    end

    # サブスクリプション用の Checkout Session を作る
    def create_checkout_session(application:, success_url:, cancel_url:)
      ensure_checkout_configured!(application.edition)

      line_item = { price: price_id_for(application.edition), quantity: 1 }
      line_item[:tax_rates] = [ ENV.fetch("STRIPE_TAX_RATE_ID") ] if ENV["STRIPE_TAX_RATE_ID"].present?

      Stripe::Checkout::Session.create(
        mode: "subscription",
        line_items: [ line_item ],
        customer_email: application.email,
        client_reference_id: application.id.to_s,
        metadata: { signup_application_id: application.id.to_s },
        success_url: success_url,
        cancel_url: cancel_url
      )
    end

    # Webhook の署名を検証してイベントを返す。不正な署名では
    # Stripe::SignatureVerificationError が上がる。
    def construct_event(payload, signature)
      Stripe::Webhook.construct_event(payload, signature, ENV.fetch("STRIPE_WEBHOOK_SECRET"))
    end

    private
      def ensure_checkout_configured!(edition)
        raise NotConfiguredError, "Stripe が設定されていません" unless checkout_configured?(edition: edition)

        Stripe.api_key = ENV.fetch("STRIPE_SECRET_KEY")
      end
  end
end

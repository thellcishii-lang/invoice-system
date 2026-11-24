# Stripe へのアクセスはすべてこのクラス経由にする（テストでは
# define_singleton_method で差し替えられるようにするため）。
# 価格ID・税率IDは環境変数から読む。金額はコードに書かない。
# 価格IDはエディション×支払い間隔で分ける（一般月払い: STRIPE_PRICE_ID /
# 建築月払い: STRIPE_PRICE_ID_CONSTRUCTION / 年払い: *_YEARLY）。
# 建築用が未設定の場合は一般用を使う（金額は同額のため）。
class StripeClient
  class NotConfiguredError < StandardError; end

  class << self
    # エディションと支払い間隔に対応する Stripe 価格ID。
    # 建築用の価格IDが未設定なら一般用にフォールバックする（金額は同額）。
    def price_id_for(edition, interval = "monthly")
      if interval.to_s == "yearly"
        (edition.to_s == "construction" && ENV["STRIPE_PRICE_ID_CONSTRUCTION_YEARLY"].presence) || ENV["STRIPE_PRICE_ID_YEARLY"]
      else
        (edition.to_s == "construction" && ENV["STRIPE_PRICE_ID_CONSTRUCTION"].presence) || ENV["STRIPE_PRICE_ID"]
      end
    end

    # 秘密鍵と、対象の価格IDが揃っていれば申込受付可能
    def checkout_configured?(edition: "general", interval: "monthly")
      ENV["STRIPE_SECRET_KEY"].present? && price_id_for(edition, interval).present?
    end

    # サブスクリプション用の Checkout Session を作る
    def create_checkout_session(application:, success_url:, cancel_url:)
      ensure_checkout_configured!(application.edition, application.billing_interval)

      line_item = { price: price_id_for(application.edition, application.billing_interval), quantity: 1 }
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
      def ensure_checkout_configured!(edition, interval = "monthly")
        raise NotConfiguredError, "Stripe が設定されていません" unless checkout_configured?(edition: edition, interval: interval)

        Stripe.api_key = ENV.fetch("STRIPE_SECRET_KEY")
      end
  end
end

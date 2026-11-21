require "test_helper"

class DocumentDeliveryTest < ActiveSupport::TestCase
  test "deliver_by_email! sends mail, marks a draft issued and records the delivery" do
    document = tenants(:one).documents.build(
      kind: "invoice", client: clients(:one), issue_date: Date.new(2026, 11, 5), title: "下書き請求"
    )
    document.document_lines.build(name: "作業費", quantity: 1, unit_price: 10000, tax_rate: "standard")
    document.save!
    document.recalculate_totals!
    assert document.draft?

    delivery = nil
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      delivery = document.deliver_by_email!("billing@sample.example.co.jp")
    end

    assert document.reload.issued?
    assert_equal "email", delivery.channel
    assert_equal "billing@sample.example.co.jp", delivery.recipient_email
    assert_equal document.tenant, delivery.tenant
    assert delivery.sent_at.present?
    assert_equal 64, delivery.token_digest.length

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "billing@sample.example.co.jp" ], mail.to
    assert_match document.number, mail.subject
  end

  test "deliver_by_email! keeps an issued document issued and adds another record" do
    document = documents(:invoice_one)
    assert document.issued?

    assert_difference("DocumentDelivery.count", 1) do
      document.deliver_by_email!("again@example.co.jp")
    end
    assert document.reload.issued?
  end

  test "deliver_by_email! rejects a blank recipient" do
    document = documents(:invoice_one)

    assert_no_difference("DocumentDelivery.count") do
      assert_raises(ArgumentError) { document.deliver_by_email!("") }
    end
  end

  test "a delivery for another tenant's document is invalid" do
    delivery = DocumentDelivery.new(
      tenant: tenants(:one), document: documents(:invoice_two),
      channel: "email", recipient_email: "a@example.co.jp", sent_at: Time.current
    )

    assert_not delivery.valid?
  end
end

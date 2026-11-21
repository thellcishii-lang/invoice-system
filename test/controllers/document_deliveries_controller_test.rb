require "test_helper"

class DocumentDeliveriesControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when unauthenticated" do
    get new_document_delivery_path(documents(:invoice_one))

    assert_redirected_to new_session_path
  end

  test "new shows the confirm screen with the client email prefilled" do
    sign_in_as(users(:one))
    clients(:document_client).update!(email: "billing@document-client.example.co.jp")

    get new_document_delivery_path(documents(:invoice_one))

    assert_response :success
    assert_match "billing@document-client.example.co.jp", response.body
    assert_match documents(:invoice_one).number, response.body
    assert_match "48,100円", response.body
  end

  test "create sends the mail and records the delivery" do
    sign_in_as(users(:one))
    document = documents(:invoice_one)

    assert_difference("DocumentDelivery.count", 1) do
      assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
        post document_delivery_path(document), params: { recipient_email: "sent-to@example.co.jp" }
      end
    end

    assert_redirected_to document_path(document)
    delivery = document.document_deliveries.first
    assert_equal "sent-to@example.co.jp", delivery.recipient_email
    assert_equal "email", delivery.channel

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "sent-to@example.co.jp" ], mail.to
    assert_match document.number, mail.subject
  end

  test "create marks a draft document as issued" do
    sign_in_as(users(:one))
    document = tenants(:one).documents.build(
      kind: "invoice", client: clients(:one), issue_date: Date.new(2026, 11, 5), title: "下書き請求"
    )
    document.document_lines.build(name: "作業費", quantity: 1, unit_price: 10000, tax_rate: "standard")
    document.save!
    document.recalculate_totals!
    assert document.draft?

    post document_delivery_path(document), params: { recipient_email: "billing@sample.example.co.jp" }

    assert_redirected_to document_path(document)
    assert document.reload.issued?
  end

  test "create with a blank recipient sends nothing and re-renders the form" do
    sign_in_as(users(:one))
    document = documents(:invoice_one)

    assert_no_difference("DocumentDelivery.count") do
      assert_no_difference -> { ActionMailer::Base.deliveries.size } do
        post document_delivery_path(document), params: { recipient_email: "" }
      end
    end

    assert_response :unprocessable_entity
  end

  test "cannot send another tenant's document" do
    sign_in_as(users(:one))

    assert_no_difference("DocumentDelivery.count") do
      post document_delivery_path(documents(:invoice_two)), params: { recipient_email: "a@example.co.jp" }
    end

    assert_response :not_found
  end

  test "show page lists the delivery history" do
    sign_in_as(users(:one))

    get document_path(documents(:invoice_one))

    assert_response :success
    assert_match "送信履歴", response.body
    assert_match "billing@document-client.example.co.jp", response.body
  end
end

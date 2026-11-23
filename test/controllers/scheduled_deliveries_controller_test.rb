require "test_helper"

class ScheduledDeliveriesControllerTest < ActionDispatch::IntegrationTest
  test "creates a reservation from the document page and lists it" do
    sign_in_as(users(:one))

    assert_difference("ScheduledDelivery.count", 1) do
      post document_scheduled_deliveries_path(documents(:invoice_one)), params: { scheduled_delivery: {
        channel: "email", email_recipient: "yoyaku@example.co.jp",
        scheduled_at: "2026-12-01T09:00"
      } }
    end
    assert_redirected_to document_path(documents(:invoice_one))

    get scheduled_deliveries_path
    assert_response :success
    assert_match "yoyaku@example.co.jp", response.body
    assert_match "送信予定", response.body
  end

  test "cancels a reservation" do
    sign_in_as(users(:one))
    reservation = tenants(:one).scheduled_deliveries.create!(
      document: documents(:invoice_one), channel: "email",
      recipient: "a@example.co.jp", scheduled_at: 1.day.from_now
    )

    post cancel_scheduled_delivery_path(reservation)

    assert_equal "cancelled", reservation.reload.status
  end

  test "redirects to login when unauthenticated" do
    get scheduled_deliveries_path

    assert_redirected_to new_session_path
  end
end

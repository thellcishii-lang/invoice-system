require "test_helper"

class ScheduledDeliveryTest < ActiveSupport::TestCase
  setup do
    @tenant = tenants(:one)
    @document = documents(:invoice_one)
  end

  test "executes a due email reservation and marks it sent" do
    reservation = @tenant.scheduled_deliveries.create!(
      document: @document, channel: "email", recipient: "a@example.co.jp",
      scheduled_at: 1.hour.ago
    )

    reservation.execute!

    assert_equal "sent", reservation.status
    assert reservation.sent_at.present?
    assert @document.document_deliveries.where(status: "sent").exists?
  end

  test "marks a fax reservation failed while the fax service is unconfigured" do
    reservation = @tenant.scheduled_deliveries.create!(
      document: @document, channel: "fax", recipient: "03-0000-0000",
      scheduled_at: 1.hour.ago
    )

    reservation.execute!

    assert_equal "failed", reservation.status
    assert_match "FAX送信サービスが未設定", reservation.error_message
  end

  test "cancel only works while pending" do
    reservation = @tenant.scheduled_deliveries.create!(
      document: @document, channel: "email", recipient: "a@example.co.jp",
      scheduled_at: 1.day.from_now
    )

    reservation.cancel!
    assert_equal "cancelled", reservation.status

    reservation.execute!
    assert_equal "cancelled", reservation.status, "取り消した予約は実行されない"
  end

  test "job executes only due pending reservations" do
    due = @tenant.scheduled_deliveries.create!(
      document: @document, channel: "email", recipient: "a@example.co.jp",
      scheduled_at: 1.hour.ago
    )
    future = @tenant.scheduled_deliveries.create!(
      document: @document, channel: "email", recipient: "a@example.co.jp",
      scheduled_at: 1.day.from_now
    )

    ScheduledDeliveriesJob.perform_now

    assert_equal "sent", due.reload.status
    assert_equal "pending", future.reload.status
  end
end

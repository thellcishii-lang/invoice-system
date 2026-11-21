require "test_helper"

class PaymentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @invoice = documents(:invoice_one) # 合計 48,100 円、入金済み 20,000 円（一部入金）
  end

  test "creates a payment and updates the invoice payment status" do
    assert_equal "partial", @invoice.payment_status

    assert_difference "Payment.count", 1 do
      post document_payments_path(@invoice), params: {
        payment: { amount: 28100, paid_on: "2026-11-25", method: "bank_transfer", note: "残金" }
      }
    end

    assert_redirected_to document_path(@invoice)
    @invoice.reload
    assert_equal "paid", @invoice.payment_status
    assert_equal 48100, @invoice.received_amount
  end

  test "rejects an invalid payment" do
    assert_no_difference "Payment.count" do
      post document_payments_path(@invoice), params: {
        payment: { amount: 0, paid_on: "2026-11-25", method: "cash" }
      }
    end

    assert_response :unprocessable_entity
    assert_equal "partial", @invoice.reload.payment_status
  end

  test "updates a payment and recalculates the status" do
    payment = payments(:payment_one)

    patch document_payment_path(@invoice, payment), params: {
      payment: { amount: 48100, paid_on: "2026-11-10", method: "bank_transfer" }
    }

    assert_redirected_to document_path(@invoice)
    assert_equal "paid", @invoice.reload.payment_status
  end

  test "destroys a payment and recalculates the status" do
    assert_difference "Payment.count", -1 do
      delete document_payment_path(@invoice, payments(:payment_one))
    end

    assert_redirected_to document_path(@invoice)
    @invoice.reload
    assert_equal "unpaid", @invoice.payment_status
    assert_equal 0, @invoice.received_amount
  end

  test "shows the payments section on the invoice page" do
    get document_path(@invoice)

    assert_response :success
    assert_match "入金済み", response.body
    assert_match "20,000円", response.body
    assert_match "28,100円", response.body # 残高
  end

  test "shows the overpayment amount when received exceeds the total" do
    @invoice.payments.create!(tenant: tenants(:one), amount: 40000, paid_on: Date.new(2026, 11, 20), method: "cash")

    get document_path(@invoice)

    assert_response :success
    assert_match "過入金", response.body
    assert_match "11,900円", response.body # 20,000 + 40,000 - 48,100
  end

  test "cannot register a payment on an estimate through the form endpoint" do
    assert_no_difference "Payment.count" do
      post document_payments_path(documents(:estimate_one)), params: {
        payment: { amount: 1000, paid_on: "2026-11-25", method: "cash" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "cannot access another tenant's invoice payments" do
    sign_out
    sign_in_as(users(:two))

    post document_payments_path(@invoice), params: {
      payment: { amount: 1000, paid_on: "2026-11-25", method: "cash" }
    }
    assert_response :not_found

    get edit_document_payment_path(@invoice, payments(:payment_one))
    assert_response :not_found

    delete document_payment_path(@invoice, payments(:payment_one))
    assert_response :not_found
  end

  test "redirects to login when unauthenticated" do
    sign_out

    post document_payments_path(@invoice), params: {
      payment: { amount: 1000, paid_on: "2026-11-25", method: "cash" }
    }

    assert_redirected_to new_session_path
  end
end

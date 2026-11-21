require "test_helper"

class UnpaidInvoicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  # 合計 11,000 円の請求書を作る
  def create_invoice(due_date:, status: "issued", tenant: tenants(:one), client: clients(:one))
    tenant.documents.build(kind: "invoice", client: client, issue_date: Date.current,
                           title: "テスト請求書", status: status, due_date: due_date).tap do |document|
      document.document_lines.build(name: "作業費", quantity: 1, unit_price: 10000, tax_rate: "standard")
      document.save!
      document.recalculate_totals!
    end
  end

  test "lists issued unpaid and partially paid invoices but not paid or draft ones" do
    unpaid = create_invoice(due_date: Date.current + 10)
    paid = create_invoice(due_date: Date.current + 5)
    paid.payments.create!(tenant: tenants(:one), amount: 11000, paid_on: Date.current, method: "cash")
    draft = create_invoice(due_date: Date.current + 3, status: "draft")

    get unpaid_invoices_path

    assert_response :success
    assert_match unpaid.number, response.body
    assert_match documents(:invoice_one).number, response.body # 一部入金のフィクスチャ
    assert_no_match paid.number, response.body
    assert_no_match draft.number, response.body
  end

  test "orders invoices by due date and sums the balances" do
    later = create_invoice(due_date: Date.current + 20)
    earlier = create_invoice(due_date: Date.current + 2)

    get unpaid_invoices_path

    assert_response :success
    assert_operator response.body.index(earlier.number), :<, response.body.index(later.number)
    # 残高合計 = 11,000 × 2 + フィクスチャの一部入金残高 28,100
    assert_match "50,100円", response.body
  end

  test "highlights overdue invoices" do
    overdue = create_invoice(due_date: Date.current - 1)

    get unpaid_invoices_path

    assert_response :success
    assert_match overdue.number, response.body
    assert_match "期限超過", response.body
  end

  test "does not show other tenants' invoices" do
    sign_out
    sign_in_as(users(:two))

    get unpaid_invoices_path

    assert_response :success
    assert_no_match documents(:invoice_one).number, response.body
    assert_match "未入金の請求書はありません", response.body
  end

  test "redirects to login when unauthenticated" do
    sign_out

    get unpaid_invoices_path

    assert_redirected_to new_session_path
  end
end

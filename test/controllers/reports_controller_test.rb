require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  # 税抜単価から合計 11,000 円（単価 10,000 円）などの請求書を作る
  # number を渡すと採番せずその番号を使う（フィクスチャと同月の番号衝突回避）
  def create_invoice(issue_date:, unit_price:, due_date: nil, number: nil)
    tenants(:one).documents.build(kind: "invoice", client: clients(:one), issue_date: issue_date,
                                  title: "テスト請求書", status: "issued", due_date: due_date, number: number).tap do |document|
      document.document_lines.build(name: "作業費", quantity: 1, unit_price: unit_price, tax_rate: "standard")
      document.save!
      document.recalculate_totals!
    end
  end

  test "shows twelve monthly rows" do
    get report_path

    assert_response :success
    assert_select "tbody tr", 12
  end

  test "aggregates billed by issue month and received by payment month" do
    this_month_invoice = create_invoice(issue_date: Date.current, unit_price: 10000) # 合計 11,000 円
    create_invoice(issue_date: Date.current << 1, unit_price: 20000, number: "TEST-202610-101") # 先月分、合計 22,000 円
    this_month_invoice.payments.create!(tenant: tenants(:one), amount: 5000, paid_on: Date.current, method: "bank_transfer")

    get report_path

    assert_response :success
    # 今月の請求額 11,000 円（フィクスチャの請求書は先月発行）
    assert_match "11,000円", response.body
    # 先月の請求額 = フィクスチャ 48,100 + 22,000 = 70,100 円
    assert_match "70,100円", response.body
    # 今月の入金額 = フィクスチャ 20,000 + 5,000 = 25,000 円
    assert_match "25,000円", response.body
  end

  test "shows current unpaid balance and overdue count summary" do
    overdue = create_invoice(issue_date: Date.current, unit_price: 10000, due_date: Date.current - 1)
    overdue.payments.create!(tenant: tenants(:one), amount: 5000, paid_on: Date.current, method: "cash")

    get report_path

    assert_response :success
    # 未入金残高 = フィクスチャ 28,100 + (11,000 - 5,000) = 34,100 円
    assert_match "34,100円", response.body
    assert_match "1件", response.body
  end

  test "redirects to login when unauthenticated" do
    sign_out

    get report_path

    assert_redirected_to new_session_path
  end
end

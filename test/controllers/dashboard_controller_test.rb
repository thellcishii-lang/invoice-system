require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when unauthenticated" do
    get root_path

    assert_redirected_to new_session_path
  end

  test "shows dashboard with own tenant name when signed in" do
    sign_in_as(users(:one))

    get root_path

    assert_response :success
    assert_select "h1", "ダッシュボード"
    assert_match ERB::Util.html_escape(tenants(:one).name), response.body
    assert_no_match ERB::Util.html_escape(tenants(:two).name), response.body
  end

  test "shows this month's billed amount, unpaid balance and overdue count" do
    sign_in_as(users(:one))
    invoice = tenants(:one).documents.build(kind: "invoice", client: clients(:one), issue_date: Date.current,
                                            title: "テスト請求書", status: "issued", due_date: Date.current - 1)
    invoice.document_lines.build(name: "作業費", quantity: 1, unit_price: 10000, tax_rate: "standard")
    invoice.save!
    invoice.recalculate_totals! # 合計 11,000 円、期限超過

    get root_path

    assert_response :success
    assert_match "今月の請求額", response.body
    assert_match "11,000円", response.body
    # 未入金残高 = フィクスチャの一部入金残高 28,100 + 11,000 = 39,100 円
    assert_match "39,100円", response.body
    assert_match "期限超過の請求書", response.body
    assert_match "1件", response.body
  end
end

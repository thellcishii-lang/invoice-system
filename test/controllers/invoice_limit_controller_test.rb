require "test_helper"

# 請求書の月間上限が画面操作でも効くことと、ダッシュボードの利用状況表示
class InvoiceLimitControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = tenants(:one)
    @tenant.update!(monthly_invoice_limit: 1)
    sign_in_as(users(:one))
  end

  test "creating an invoice over the limit is rejected with an error message" do
    create_invoice
    assert_redirected_to document_path(Document.last)

    assert_no_difference "Document.count" do
      create_invoice
    end
    assert_response :unprocessable_entity
    assert_match "発行上限（1通）に達しました", response.body
  end

  test "dashboard shows this month's invoice usage" do
    get root_path

    assert_response :success
    assert_match "今月の請求書", response.body
    assert_match "0 / 1通", response.body
  end

  test "dashboard shows unlimited for a tenant without a limit" do
    @tenant.update!(monthly_invoice_limit: nil)

    get root_path

    assert_response :success
    assert_match "（無制限）", response.body
  end

  private
    def create_invoice
      post documents_path, params: {
        document: {
          kind: "invoice", client_id: clients(:one).id, issue_date: Date.current,
          document_lines_attributes: [ { name: "作業費", quantity: 1, unit_price: 1000, tax_rate: "standard" } ]
        }
      }
    end
end

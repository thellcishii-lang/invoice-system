require "test_helper"

# 請求書の月間作成上限（テナントの monthly_invoice_limit）の検証。
# 上限は発行日の属する月で数え、NULL のテナントは無制限。
class InvoiceLimitTest < ActiveSupport::TestCase
  setup do
    @tenant = Tenant.create!(name: "上限テスト株式会社")
    @client = @tenant.clients.create!(name: "取引先株式会社")
  end

  test "creates invoices up to the limit and rejects the next one" do
    @tenant.update!(monthly_invoice_limit: 2)

    assert build_invoice.save
    assert build_invoice.save

    over = build_invoice
    assert_not over.save
    assert_includes over.errors[:base].join, "発行上限（2通）に達しました"
  end

  test "100th invoice is allowed and 101st is rejected with the default limit" do
    assert_equal 100, @tenant.monthly_invoice_limit

    100.times { assert build_invoice.save }
    assert_equal 100, @tenant.invoice_count_for(Date.current)

    over = build_invoice
    assert_not over.save
    assert_includes over.errors[:base].join, "発行上限（100通）に達しました"
  end

  test "tenant with nil limit is unlimited" do
    @tenant.update!(monthly_invoice_limit: nil)

    3.times { assert build_invoice.save }
    assert_not @tenant.invoice_limit_reached?
  end

  test "invoices issued in another month do not count" do
    @tenant.update!(monthly_invoice_limit: 1)

    assert build_invoice(issue_date: Date.current.last_month).save
    assert build_invoice(issue_date: Date.current).save
    assert_not build_invoice(issue_date: Date.current).save
  end

  test "estimates are not capped and do not count toward the limit" do
    @tenant.update!(monthly_invoice_limit: 1)

    assert build_invoice.save
    estimate = @tenant.documents.build(kind: "estimate", client: @client, issue_date: Date.current)
    estimate.document_lines.build(name: "作業費", quantity: 1, unit_price: 1000, tax_rate: "standard")
    assert estimate.save
  end

  private
    def build_invoice(issue_date: Date.current)
      document = @tenant.documents.build(kind: "invoice", client: @client, issue_date: issue_date)
      document.document_lines.build(name: "作業費", quantity: 1, unit_price: 1000, tax_rate: "standard")
      document
    end
end

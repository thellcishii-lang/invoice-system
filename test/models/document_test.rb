require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  def build_document(tenant:, client:, kind: "invoice", issue_date: Date.new(2026, 11, 5))
    tenant.documents.build(kind: kind, client: client, issue_date: issue_date, title: "テスト帳票").tap do |document|
      document.document_lines.build(name: "作業費", quantity: 1, unit_price: 10000, tax_rate: "standard")
    end
  end

  # --- 採番 ---

  test "assigns a sequential number with year-month at creation" do
    document = build_document(tenant: tenants(:one), client: clients(:one))
    document.save!

    assert_equal "202611-001", document.number

    second = build_document(tenant: tenants(:one), client: clients(:one))
    second.save!

    assert_equal "202611-002", second.number
  end

  test "sequences are independent per kind" do
    invoice = build_document(tenant: tenants(:one), client: clients(:one), kind: "invoice")
    invoice.save!
    estimate = build_document(tenant: tenants(:one), client: clients(:one), kind: "estimate")
    estimate.save!

    assert_equal "202611-001", invoice.number
    assert_equal "202611-001", estimate.number
  end

  test "sequences are independent per month" do
    november = build_document(tenant: tenants(:one), client: clients(:one), issue_date: Date.new(2026, 11, 5))
    november.save!
    december = build_document(tenant: tenants(:one), client: clients(:one), issue_date: Date.new(2026, 12, 1))
    december.save!

    assert_equal "202611-001", november.number
    assert_equal "202612-001", december.number
  end

  test "applies the tenant document number prefix" do
    document = build_document(tenant: tenants(:two), client: clients(:two))
    document.save!

    assert_equal "TS-202611-001", document.number
  end

  test "numbers are never reused after deletion" do
    first = build_document(tenant: tenants(:one), client: clients(:one))
    first.save!
    second = build_document(tenant: tenants(:one), client: clients(:one))
    second.save!
    assert_equal "202611-002", second.number

    second.destroy!

    third = build_document(tenant: tenants(:one), client: clients(:one))
    third.save!
    assert_equal "202611-003", third.number
  end

  test "defaults issue_date to today and numbers from it" do
    document = tenants(:one).documents.build(kind: "invoice", client: clients(:one), title: "日付なし")
    document.document_lines.build(name: "作業費", quantity: 1, unit_price: 1000)
    document.save!

    assert_equal Date.current, document.issue_date
    assert_equal "#{Date.current.strftime('%Y%m')}-001", document.number
  end

  # --- バリデーション ---

  test "requires at least one line" do
    document = tenants(:one).documents.build(kind: "invoice", client: clients(:one), issue_date: Date.new(2026, 11, 5))

    assert_not document.valid?
    assert document.errors[:document_lines].any?
  end

  test "rejects a client belonging to another tenant" do
    document = build_document(tenant: tenants(:one), client: clients(:two))

    assert_not document.valid?
    assert document.errors[:client].any?
  end

  # --- 合計の再計算 ---

  test "recalculate_totals! stores subtotal, tax, total and breakdown" do
    document = tenants(:one).documents.build(
      kind: "invoice", client: clients(:one), issue_date: Date.new(2026, 11, 5), title: "合計テスト"
    )
    document.document_lines.build(name: "標準品目", quantity: 1, unit_price: 39800, tax_rate: "standard")
    document.document_lines.build(name: "軽減品目", quantity: 1, unit_price: 4000, tax_rate: "reduced")
    document.save!
    document.recalculate_totals!

    assert_equal 43800, document.subtotal
    assert_equal 4300, document.tax_amount
    assert_equal 48100, document.total
    assert_equal({ "subtotal" => 39800, "tax" => 3980 }, document.tax_breakdown["standard"])
    assert_equal({ "subtotal" => 4000, "tax" => 320 }, document.tax_breakdown["reduced"])
  end

  # --- 変換 ---

  test "converts an invoice to a receipt copying client, title and lines" do
    invoice = documents(:invoice_one)
    document_lines(:invoice_line_standard).update!(item: items(:one))

    receipt = invoice.convert_to("receipt")

    assert receipt.persisted?
    assert_equal "receipt", receipt.kind
    assert_equal invoice.client, receipt.client
    assert_equal invoice.title, receipt.title
    assert_equal invoice, receipt.converted_from
    assert_equal Date.current, receipt.issue_date
    assert_equal "draft", receipt.status
    assert receipt.number.present?
    assert_not_equal invoice.number, receipt.number

    assert_equal 2, receipt.document_lines.size
    standard = receipt.document_lines.find { |line| line.tax_rate == "standard" }
    assert_equal "システム利用料", standard.name
    assert_equal 39800, standard.unit_price
    assert_equal items(:one), standard.item

    assert_equal 43800, receipt.subtotal
    assert_equal 4300, receipt.tax_amount
    assert_equal 48100, receipt.total
  end

  test "conversion leaves the original unchanged" do
    invoice = documents(:invoice_one)

    invoice.convert_to("receipt")

    invoice.reload
    assert_equal "invoice", invoice.kind
    assert_equal 2, invoice.document_lines.size
    assert_equal 48100, invoice.total
    assert_equal 1, invoice.conversions.size
  end

  test "allows estimate to invoice directly" do
    estimate = documents(:estimate_one)

    invoice = estimate.convert_to("invoice")

    assert_equal "invoice", invoice.kind
    assert_equal estimate, invoice.converted_from
    assert_equal 43780, invoice.total
  end

  test "rejects conversions that are not allowed" do
    assert_raises(ArgumentError) { documents(:estimate_one).convert_to("receipt") }
    assert_raises(ArgumentError) { documents(:invoice_one).convert_to("estimate") }
    assert_raises(ArgumentError) { documents(:invoice_one).convert_to("invoice") }
  end
end

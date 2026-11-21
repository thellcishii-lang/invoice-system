require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  # 合計 11,000 円（税抜 10,000 円 + 消費税 10%）の発行済み請求書を作る
  def build_invoice(tenant: tenants(:one), client: clients(:one), due_date: nil)
    tenant.documents.build(kind: "invoice", client: client, issue_date: Date.new(2026, 11, 5),
                           title: "テスト請求書", status: "issued", due_date: due_date).tap do |document|
      document.document_lines.build(name: "作業費", quantity: 1, unit_price: 10000, tax_rate: "standard")
      document.save!
      document.recalculate_totals!
    end
  end

  def pay(document, amount, paid_on: Date.new(2026, 11, 20))
    document.payments.create!(tenant: document.tenant, amount: amount, paid_on: paid_on, method: "bank_transfer")
  end

  test "new invoice starts unpaid and other kinds have no payment status" do
    invoice = build_invoice
    assert_equal 11000, invoice.total
    assert_equal "unpaid", invoice.payment_status

    estimate = tenants(:one).documents.build(kind: "estimate", client: clients(:one), issue_date: Date.new(2026, 11, 5))
    estimate.document_lines.build(name: "作業費", quantity: 1, unit_price: 10000, tax_rate: "standard")
    estimate.save!
    assert_nil estimate.payment_status
  end

  test "status transitions from unpaid to partial to paid as payments are added" do
    invoice = build_invoice

    pay(invoice, 5000)
    invoice.reload
    assert_equal "partial", invoice.payment_status
    assert_equal 5000, invoice.received_amount
    assert_equal 6000, invoice.balance

    pay(invoice, 6000)
    invoice.reload
    assert_equal "paid", invoice.payment_status
    assert_equal 11000, invoice.received_amount
    assert_equal 0, invoice.balance
  end

  test "status goes back to partial and unpaid when payments are deleted" do
    invoice = build_invoice
    first = pay(invoice, 5000)
    second = pay(invoice, 6000)
    assert_equal "paid", invoice.reload.payment_status

    second.destroy!
    assert_equal "partial", invoice.reload.payment_status

    first.destroy!
    invoice.reload
    assert_equal "unpaid", invoice.payment_status
    assert_equal 0, invoice.received_amount
  end

  test "status follows payment amount updates" do
    invoice = build_invoice
    payment = pay(invoice, 5000)
    assert_equal "partial", invoice.reload.payment_status

    payment.update!(amount: 11000)
    assert_equal "paid", invoice.reload.payment_status

    payment.update!(amount: 1000)
    assert_equal "partial", invoice.reload.payment_status
  end

  test "overpayment marks the invoice paid and balance goes negative" do
    invoice = build_invoice

    pay(invoice, 15000)
    invoice.reload
    assert_equal "paid", invoice.payment_status
    assert_equal 15000, invoice.received_amount
    assert_equal(-4000, invoice.balance)
  end

  test "rejects a payment for a non-invoice document" do
    payment = tenants(:one).payments.build(
      document: documents(:estimate_one), amount: 1000,
      paid_on: Date.new(2026, 11, 20), method: "cash"
    )

    assert_not payment.valid?
    assert_includes payment.errors[:document], "は請求書ではありません"
  end

  test "rejects a payment whose document belongs to another tenant" do
    payment = tenants(:two).payments.build(
      document: documents(:invoice_one), amount: 1000,
      paid_on: Date.new(2026, 11, 20), method: "cash"
    )

    assert_not payment.valid?
    assert_includes payment.errors[:document], "は自社の帳票ではありません"
  end

  test "requires a positive integer amount, a paid_on date and a known method" do
    invoice = build_invoice

    [ 0, -100 ].each do |amount|
      payment = invoice.payments.build(tenant: tenants(:one), amount: amount, paid_on: Date.new(2026, 11, 20), method: "cash")
      assert_not payment.valid?, "amount=#{amount} は無効なはず"
    end

    payment = invoice.payments.build(tenant: tenants(:one), amount: 1000, paid_on: nil, method: "cash")
    assert_not payment.valid?

    payment = invoice.payments.build(tenant: tenants(:one), amount: 1000, paid_on: Date.new(2026, 11, 20), method: "bitcoin")
    assert_not payment.valid?
  end

  test "method labels are japanese" do
    assert_equal "振込", Payment.new(method: "bank_transfer").method_label
    assert_equal "現金", Payment.new(method: "cash").method_label
    assert_equal "カード", Payment.new(method: "card").method_label
    assert_equal "その他", Payment.new(method: "other").method_label
  end

  test "overdue? is true only for issued invoices past due and not fully paid" do
    today = Date.new(2026, 11, 22)
    overdue = build_invoice(due_date: Date.new(2026, 11, 21))
    assert overdue.overdue?(today)

    not_yet_due = build_invoice(due_date: Date.new(2026, 11, 22))
    assert_not not_yet_due.overdue?(today)

    paid_invoice = build_invoice(due_date: Date.new(2026, 11, 1))
    pay(paid_invoice, 11000)
    assert_not paid_invoice.reload.overdue?(today)
  end
end

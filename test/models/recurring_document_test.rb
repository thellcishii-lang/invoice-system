require "test_helper"

class RecurringDocumentTest < ActiveSupport::TestCase
  def build_schedule(day_of_month: 10, template: documents(:invoice_one), **attrs)
    RecurringDocument.new(
      tenant: template.tenant, client: template.client, template_document: template,
      day_of_month: day_of_month, **attrs
    )
  end

  test "next_occurrence returns this month's day when it is still ahead" do
    schedule = build_schedule(day_of_month: 10)

    assert_equal Date.new(2026, 11, 10), schedule.next_occurrence(Date.new(2026, 11, 5))
    assert_equal Date.new(2026, 11, 10), schedule.next_occurrence(Date.new(2026, 11, 10))
  end

  test "next_occurrence rolls to next month once the day has passed" do
    schedule = build_schedule(day_of_month: 10)

    assert_equal Date.new(2026, 12, 10), schedule.next_occurrence(Date.new(2026, 11, 11))
  end

  test "next_run_date is set on create" do
    schedule = build_schedule(day_of_month: 28)
    schedule.save!

    assert schedule.next_run_date.present?
    assert_equal 28, schedule.next_run_date.day
    assert schedule.next_run_date >= Date.current
  end

  test "day_of_month must be within 1..28" do
    assert_not build_schedule(day_of_month: 0).valid?
    assert_not build_schedule(day_of_month: 29).valid?
    assert build_schedule(day_of_month: 28).valid?
  end

  test "template must be an invoice" do
    schedule = build_schedule(template: documents(:estimate_one))

    assert_not schedule.valid?
  end

  test "template must belong to the same tenant and match the client" do
    schedule = RecurringDocument.new(
      tenant: tenants(:one), client: clients(:one), template_document: documents(:invoice_two), day_of_month: 10
    )

    assert_not schedule.valid?
  end

  test "generate_document! copies lines and totals and derives the due date" do
    schedule = build_schedule
    schedule.save!

    # テンプレートは発行 2026-10-10・期限 2026-11-30 → 1ヶ月後の30日が期限になる
    document = schedule.generate_document!(Date.new(2026, 12, 5))

    assert document.invoice?
    assert document.draft?
    assert_equal Date.new(2026, 12, 5), document.issue_date
    assert_equal Date.new(2027, 1, 30), document.due_date
    assert_equal documents(:invoice_one).title, document.title
    assert_equal documents(:invoice_one).client, document.client
    assert_equal 2, document.document_lines.size
    assert_equal 43800, document.subtotal
    assert_equal 4300, document.tax_amount
    assert_equal 48100, document.total
    assert_match "202612-", document.number
  end

  test "generate_document! falls back to month-end when the template has no due date" do
    template = tenants(:one).documents.build(
      kind: "invoice", client: clients(:one), issue_date: Date.new(2026, 9, 10), title: "期限なし請求"
    )
    template.document_lines.build(name: "作業費", quantity: 1, unit_price: 10000, tax_rate: "standard")
    template.save!
    template.recalculate_totals!

    schedule = build_schedule(template: template)
    document = schedule.generate_document!(Date.new(2026, 12, 5))

    assert_equal Date.new(2026, 12, 31), document.due_date
  end

  test "run! advances the schedule" do
    schedule = build_schedule(day_of_month: 5)
    schedule.update!(next_run_date: Date.new(2026, 12, 5))

    document = schedule.run!(Date.new(2026, 12, 5))

    assert document.persisted?
    assert_equal Date.new(2026, 12, 5), schedule.reload.last_run_date
    assert_equal Date.new(2027, 1, 5), schedule.next_run_date
  end
end

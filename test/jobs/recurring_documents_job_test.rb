require "test_helper"

class RecurringDocumentsJobTest < ActiveJob::TestCase
  # テンプレートの発行月はフィクスチャ帳票（2026年10月）と採番が衝突しない月に置く
  def build_template(client:, issue_date: Date.new(2026, 9, 10), due_date: Date.new(2026, 10, 30))
    document = tenants(:one).documents.build(
      kind: "invoice", client: client, issue_date: issue_date, due_date: due_date, title: "月額利用料"
    )
    document.document_lines.build(name: "システム利用料", quantity: 1, unit: "月", unit_price: 39800, tax_rate: "standard")
    document.document_lines.build(name: "新聞購読料", quantity: 2, unit: "月", unit_price: 2000, tax_rate: "reduced")
    document.save!
    document.recalculate_totals!
    document
  end

  def build_schedule(template:, day_of_month: 5, next_run_date:, auto_send: false, active: true)
    RecurringDocument.create!(
      tenant: template.tenant, client: template.client, template_document: template,
      day_of_month: day_of_month, next_run_date: next_run_date, auto_send: auto_send, active: active
    )
  end

  test "creates an invoice on the due date with copied lines and correct totals" do
    template = build_template(client: clients(:one))
    schedule = build_schedule(template: template, next_run_date: Date.new(2026, 12, 5))
    today = Date.new(2026, 12, 5)

    document = nil
    assert_difference("Document.count", 1) do
      RecurringDocumentsJob.perform_now(today)
      document = Document.where(client: clients(:one), issue_date: today).order(:id).last
    end

    assert document.invoice?
    assert document.draft?
    assert_equal "月額利用料", document.title
    assert_equal 2, document.document_lines.size
    assert_equal [ "システム利用料", "新聞購読料" ], document.document_lines.map(&:name)
    assert_equal 43800, document.subtotal
    assert_equal 4300, document.tax_amount
    assert_equal 48100, document.total
    assert_equal Date.new(2027, 1, 30), document.due_date
    assert_match "202612-", document.number

    schedule.reload
    assert_equal today, schedule.last_run_date
    assert_equal Date.new(2027, 1, 5), schedule.next_run_date
  end

  test "does nothing when the schedule is not due yet" do
    template = build_template(client: clients(:one))
    build_schedule(template: template, next_run_date: Date.new(2026, 12, 6))

    assert_no_difference("Document.count") do
      RecurringDocumentsJob.perform_now(Date.new(2026, 12, 5))
    end
  end

  test "does nothing for an inactive schedule even when overdue" do
    template = build_template(client: clients(:one))
    build_schedule(template: template, next_run_date: Date.new(2026, 12, 1), active: false)

    assert_no_difference("Document.count") do
      RecurringDocumentsJob.perform_now(Date.new(2026, 12, 5))
    end
  end

  test "auto_send delivers the mail and marks the invoice issued" do
    template = build_template(client: clients(:one)) # clients(:one) にはメールアドレスがある
    build_schedule(template: template, next_run_date: Date.new(2026, 12, 5), auto_send: true)
    today = Date.new(2026, 12, 5)

    assert_difference("DocumentDelivery.count", 1) do
      assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
        RecurringDocumentsJob.perform_now(today)
      end
    end

    document = Document.where(client: clients(:one), issue_date: today).order(:id).last
    assert document.issued?
    delivery = document.document_deliveries.first
    assert_equal clients(:one).email, delivery.recipient_email
    assert_equal "email", delivery.channel
  end

  test "auto_send without a client email creates a draft and sends nothing" do
    template = build_template(client: clients(:document_client)) # メールアドレスなし
    build_schedule(template: template, next_run_date: Date.new(2026, 12, 5), auto_send: true)
    today = Date.new(2026, 12, 5)

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      RecurringDocumentsJob.perform_now(today)
    end

    document = Document.where(client: clients(:document_client), issue_date: today).order(:id).last
    assert document.draft?
    assert_empty document.document_deliveries
  end
end

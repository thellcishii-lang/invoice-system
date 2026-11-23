require "test_helper"

class DocumentTemplateTest < ActiveSupport::TestCase
  test "build_document copies kind, title, notes and lines, with estimate due default" do
    tenant = tenants(:one)
    template = tenant.document_templates.create!(
      kind: "estimate", name: "月額保守の見積", title: "保守契約のお見積り", notes: "備考メモ"
    )
    template.document_template_lines.create!(name: "保守料", quantity: 2, unit_price: 15000, tax_rate: "standard")

    document = template.build_document

    assert_equal "estimate", document.kind_value
    assert_equal "保守契約のお見積り", document.title
    assert_equal "備考メモ", document.notes
    assert_equal Date.current, document.issue_date
    assert_equal Date.current + 30.days, document.due_date
    assert document.draft?
    assert_equal 1, document.document_lines.size
    line = document.document_lines.first
    assert_equal "保守料", line.name
    assert_equal 2, line.quantity
    assert_equal 15000, line.unit_price
  end

  test "from_document copies an existing document into a template" do
    document = documents(:invoice_one)

    template = DocumentTemplate.from_document(document)

    assert_equal "invoice", template.kind
    assert_equal document.title, template.title
    assert_equal document.document_lines.size, template.document_template_lines.size
    assert template.save
  end

  test "lines_total sums line amounts" do
    tenant = tenants(:one)
    template = tenant.document_templates.create!(kind: "invoice", name: "t")
    template.document_template_lines.create!(name: "a", quantity: 2, unit_price: 1000)

    assert_equal 2000, template.reload.lines_total
  end
end

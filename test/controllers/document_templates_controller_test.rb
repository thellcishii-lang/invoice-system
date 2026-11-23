require "test_helper"

class DocumentTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @tenant = tenants(:one)
  end

  test "creates a template with lines and lists it by kind" do
    assert_difference "DocumentTemplate.count", 1 do
      post document_templates_path, params: {
        kind: "invoice",
        document_template: {
          name: "月次請求テンプレート", title: "月次利用料のご請求",
          document_template_lines_attributes: {
            "0" => { name: "システム利用料", quantity: 1, unit_price: 39800, tax_rate: "standard" }
          }
        }
      }
    end

    template = DocumentTemplate.last
    assert_equal "invoice", template.kind
    assert_equal 1, template.document_template_lines.count

    get document_templates_path(kind: "invoice")
    assert_response :success
    assert_includes response.body, "月次請求テンプレート"

    get document_templates_path(kind: "estimate")
    assert_not_includes response.body, "月次請求テンプレート"
  end

  test "new document from template is prefilled" do
    template = @tenant.document_templates.create!(kind: "estimate", name: "t", title: "テンプレート件名")
    template.document_template_lines.create!(name: "工事一式", quantity: 1, unit_price: 500000)

    get new_document_path(template_id: template.id)

    assert_response :success
    assert_includes response.body, "テンプレート件名"
    assert_includes response.body, "工事一式"
  end

  test "save_as_template copies a document and redirects to template edit" do
    document = documents(:invoice_one)

    assert_difference "DocumentTemplate.count", 1 do
      post save_as_template_document_path(document)
    end

    template = DocumentTemplate.last
    assert_equal "invoice", template.kind
    assert_redirected_to edit_document_template_path(template)
  end

  test "destroys a template" do
    template = @tenant.document_templates.create!(kind: "receipt", name: "t")

    assert_difference "DocumentTemplate.count", -1 do
      delete document_template_path(template)
    end
    assert_redirected_to document_templates_path(kind: "receipt")
  end
end

require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when unauthenticated" do
    get documents_path

    assert_redirected_to new_session_path
  end

  test "index shows only own tenant documents" do
    sign_in_as(users(:one))

    get documents_path

    assert_response :success
    assert_match documents(:invoice_one).number, response.body
    assert_no_match ERB::Util.html_escape(documents(:invoice_two).number), response.body
    assert_no_match ERB::Util.html_escape(clients(:two).name), response.body
  end

  test "index filters by kind" do
    sign_in_as(users(:one))

    get documents_path(kind: "invoice")

    assert_response :success
    assert_match ERB::Util.html_escape(documents(:invoice_one).title), response.body
    assert_no_match ERB::Util.html_escape(documents(:estimate_one).title), response.body
  end

  test "new estimate defaults the validity date to 30 days after issue" do
    sign_in_as(users(:one))

    get new_document_path(kind: "estimate")

    assert_response :success
    assert_select "input[name='document[due_date]'][value=?]", (Date.current + 30.days).strftime("%Y-%m-%d")
    assert_match "見積有効期限", response.body
  end

  test "new invoice does not default the due date" do
    sign_in_as(users(:one))

    get new_document_path(kind: "invoice")

    assert_response :success
    assert_select "input[name='document[due_date]']" do |elements|
      assert_nil elements.first["value"]
    end
    assert_match "お支払期限", response.body
  end

  test "new renders the form with a line row and item options" do
    sign_in_as(users(:one))

    get new_document_path(kind: "invoice")

    assert_response :success
    assert_match "document_lines", response.body
    assert_match ERB::Util.html_escape(items(:one).name), response.body
  end

  test "show renders lines, totals and tax breakdown" do
    sign_in_as(users(:one))

    get document_path(documents(:invoice_one))

    assert_response :success
    assert_match "システム利用料", response.body
    assert_match "新聞購読料", response.body
    assert_match "48,100円", response.body
    assert_match "領収書に変換", response.body
  end

  test "edit renders the form with existing lines" do
    sign_in_as(users(:one))

    get edit_document_path(documents(:invoice_one))

    assert_response :success
    assert_match "システム利用料", response.body
  end

  test "creates a document with lines, an assigned number and computed totals" do
    sign_in_as(users(:one))

    assert_difference("Document.count", 1) do
      post documents_path, params: { document: {
        kind: "invoice",
        client_id: clients(:one).id,
        issue_date: "2026-11-05",
        title: "テスト請求",
        status: "draft",
        document_lines_attributes: [
          { name: "作業費", quantity: 1, unit_price: 10000, tax_rate: "standard" }
        ]
      } }
    end

    document = Document.order(:id).last
    assert_redirected_to document_path(document)
    assert_equal tenants(:one), document.tenant
    assert_equal "202611-001", document.number
    assert_equal 10000, document.subtotal
    assert_equal 1000, document.tax_amount
    assert_equal 11000, document.total
    assert_equal 10000, document.document_lines.first.amount
  end

  test "creates a document from an item picker selection" do
    sign_in_as(users(:one))

    post documents_path, params: { document: {
      kind: "estimate",
      client_id: clients(:one).id,
      issue_date: "2026-11-05",
      document_lines_attributes: [
        { item_id: items(:one).id, name: items(:one).name, quantity: 2, unit: "月", unit_price: items(:one).unit_price, tax_rate: "standard" }
      ]
    } }

    document = Document.order(:id).last
    assert_redirected_to document_path(document)
    assert_equal items(:one), document.document_lines.first.item
    assert_equal 79600, document.subtotal
  end

  test "cannot create a document for another tenant's client" do
    sign_in_as(users(:one))

    assert_no_difference("Document.count") do
      post documents_path, params: { document: {
        kind: "invoice",
        client_id: clients(:two).id,
        issue_date: "2026-11-05",
        document_lines_attributes: [
          { name: "作業費", quantity: 1, unit_price: 10000, tax_rate: "standard" }
        ]
      } }
    end

    assert_response :unprocessable_entity
  end

  test "cannot show another tenant's document" do
    sign_in_as(users(:one))

    get document_path(documents(:invoice_two))

    assert_response :not_found
  end

  test "cannot edit another tenant's document" do
    sign_in_as(users(:one))

    get edit_document_path(documents(:invoice_two))

    assert_response :not_found
  end

  test "cannot update another tenant's document" do
    sign_in_as(users(:one))

    patch document_path(documents(:invoice_two)), params: { document: { title: "乗っ取り" } }

    assert_response :not_found
    assert_equal "工事代金", documents(:invoice_two).reload.title
  end

  test "cannot destroy another tenant's document" do
    sign_in_as(users(:one))

    assert_no_difference("Document.count") do
      delete document_path(documents(:invoice_two))
    end

    assert_response :not_found
    assert Document.exists?(documents(:invoice_two).id)
  end

  test "cannot print another tenant's document" do
    sign_in_as(users(:one))

    get print_document_path(documents(:invoice_two))

    assert_response :not_found
  end

  test "updates own document and recomputes totals" do
    sign_in_as(users(:one))
    document = documents(:invoice_one)
    line = document_lines(:invoice_line_standard)

    patch document_path(document), params: { document: {
      title: "変更後の件名",
      document_lines_attributes: [
        { id: line.id, name: line.name, quantity: 1, unit: "月", unit_price: 20000, tax_rate: "standard" }
      ]
    } }

    assert_redirected_to document_path(document)
    document.reload
    assert_equal "変更後の件名", document.title
    assert_equal "invoice", document.kind
    # 標準 20000 + 税2000、軽減 4000 + 税320（未指定の明細は残る）
    assert_equal 24000, document.subtotal
    assert_equal 2320, document.tax_amount
    assert_equal 26320, document.total
  end

  test "destroys own document" do
    sign_in_as(users(:one))

    assert_difference("Document.count", -1) do
      delete document_path(documents(:estimate_one))
    end

    assert_redirected_to documents_path(kind: "estimate")
  end

  test "duplicates a document via POST" do
    sign_in_as(users(:one))
    original = documents(:invoice_one)

    assert_difference("Document.count", 1) do
      post duplicate_document_path(original)
    end

    copy = Document.order(:id).last
    assert_redirected_to edit_document_path(copy)
    assert_equal original.kind, copy.kind
    assert_not_equal original.number, copy.number
    assert_equal "draft", copy.status
    assert_equal original.total, copy.total
    assert_equal original.document_lines.count, copy.document_lines.count
    assert_empty copy.payments
    # 支払期限は発行日からの日数を引き継ぐ
    assert_equal (original.due_date - original.issue_date).to_i, (copy.due_date - copy.issue_date).to_i
  end

  test "creates an order document and converts estimate to order to delivery" do
    sign_in_as(users(:one))

    assert_difference("Document.count", 1) do
      post documents_path, params: { document: {
        kind: "order", client_id: clients(:one).id, issue_date: "2026-11-23", due_date: "2026-12-10",
        document_lines_attributes: { "0" => { name: "部品一式", quantity: 1, unit_price: 50000, tax_rate: "standard" } }
      } }
    end
    order = Document.order(:id).last
    assert order.purchase_order?
    assert_equal "発注書", order.kind_label

    converted = documents(:estimate_one).convert_to("order")
    assert converted.purchase_order?
    delivered = converted.convert_to("delivery")
    assert delivered.delivery?
  end

  test "order print shows the order band labels and delivery deadline" do
    sign_in_as(users(:one))
    order = tenants(:one).documents.build(
      kind: "order", client: clients(:one), issue_date: Date.new(2026, 11, 23),
      due_date: Date.new(2026, 12, 10), title: "部品発注"
    )
    order.document_lines.build(name: "部品一式", quantity: 1, unit_price: 50000, tax_rate: "standard", position: 1)
    order.save!
    order.recalculate_totals!

    get print_document_path(order)

    assert_response :success
    assert_match "発注書", response.body
    assert_match "発注金額", response.body
    assert_match "納期", response.body
  end

  test "print reflects the tenant design settings (custom color, stripes, pattern)" do
    sign_in_as(users(:one))
    tenants(:one).update!(document_color: "#ff0000", document_striped: true, document_pattern: "dots")

    get print_document_path(documents(:invoice_one))

    assert_response :success
    assert_match "#ffd1d1", response.body, "帯はカスタム色の淡色になる"
    assert_match "nth-child(even)", response.body, "シマシマのCSSが入る"
    assert_match "radial-gradient", response.body, "背景の柄（ドット）が入る"
  end

  test "converts a document via POST" do
    sign_in_as(users(:one))

    assert_difference("Document.count", 1) do
      post convert_document_path(documents(:invoice_one), target_kind: "receipt")
    end

    converted = Document.order(:id).last
    assert_redirected_to document_path(converted)
    assert_equal "receipt", converted.kind
    assert_equal documents(:invoice_one), converted.converted_from
    assert_equal 48100, converted.total
  end

  test "rejects an invalid conversion via POST" do
    sign_in_as(users(:one))

    assert_no_difference("Document.count") do
      post convert_document_path(documents(:invoice_one), target_kind: "estimate")
    end

    assert_redirected_to document_path(documents(:invoice_one))
  end

  test "print renders a qualified invoice with issuer registration number" do
    sign_in_as(users(:one))

    get print_document_path(documents(:invoice_one))

    assert_response :success
    assert_match "請求書", response.body
    assert_match tenants(:one).invoice_registration_number, response.body
    assert_match ERB::Util.html_escape(clients(:document_client).name), response.body
    assert_match "48,100円", response.body
    assert_match "10%", response.body
    assert_match "8%", response.body
  end
end

class ConstructionPrintTest < ActionDispatch::IntegrationTest
  test "construction print shows cover, summary by category, and per-category details" do
    sign_in_as(users(:one))
    tenant = tenants(:one)
    category = tenant.item_categories.create!(name: "内装工事")
    item = tenant.items.create!(name: "壁クロス貼り", item_category: category)
    estimate = tenant.documents.build(kind: "estimate", client: clients(:one),
      issue_date: Date.new(2026, 11, 23), due_date: Date.new(2026, 12, 23), title: "店舗改装工事")
    estimate.document_lines.build(item: item, name: "壁クロス貼り", quantity: 10, unit: "m2", unit_price: 1500, tax_rate: "standard", position: 1)
    estimate.document_lines.build(name: "諸経費", quantity: 1, unit_price: 5000, tax_rate: "standard", position: 2)
    estimate.save!
    estimate.recalculate_totals!

    get construction_print_document_path(estimate)

    assert_response :success
    assert_match "御見積金額", response.body
    assert_match "内訳書", response.body
    assert_match "内装工事", response.body
    assert_match "その他", response.body
    assert_match "A4 landscape", response.body
  end

  test "estimate page offers the construction print for construction tenants" do
    sign_in_as(users(:one))
    tenants(:one).update!(edition: "construction")

    get document_path(documents(:estimate_one))

    assert_response :success
    assert_match "建築様式", response.body
  end
end

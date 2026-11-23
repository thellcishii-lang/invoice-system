require "test_helper"

class DocumentsFilterTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @tenant = tenants(:one)
    @client_a = @tenant.clients.create!(name: "アルファ商事", contact_person: "田中")
    @client_b = @tenant.clients.create!(name: "ベータ工業", contact_person: "鈴木")

    @doc_a = make_document(client: @client_a, title: "保守契約の請求", lines: [ "保守料" ],
                           issue_date: Date.new(2026, 11, 5), notes: "振込手数料は貴社負担", internal_memo: "値引き交渉中")
    @doc_b = make_document(client: @client_b, title: "工事代金の請求", lines: [ "工事一式" ],
                           issue_date: Date.new(2026, 11, 20))
  end

  def make_document(client:, title:, lines:, issue_date:, notes: nil, internal_memo: nil)
    document = @tenant.documents.build(kind: "invoice", client: client, title: title,
                                       issue_date: issue_date, due_date: issue_date + 14,
                                       status: "issued", notes: notes, internal_memo: internal_memo)
    lines.each { |name| document.document_lines.build(name: name, quantity: 1, unit_price: 10000) }
    document.save!
    document.recalculate_totals!
    document
  end

  def numbers_in(body)
    body.scan(%r{/documents/(\d+)}).flatten.map(&:to_i)
  end

  test "filters by client, title, line name, notes and internal memo" do
    get documents_path(kind: "invoice", f: { client_id: @client_a.id })
    assert_includes numbers_in(response.body), @doc_a.id
    assert_not_includes numbers_in(response.body), @doc_b.id

    get documents_path(kind: "invoice", f: { title: "保守" })
    assert_includes numbers_in(response.body), @doc_a.id
    assert_not_includes numbers_in(response.body), @doc_b.id

    get documents_path(kind: "invoice", f: { line_name: "工事" })
    assert_includes numbers_in(response.body), @doc_b.id
    assert_not_includes numbers_in(response.body), @doc_a.id

    get documents_path(kind: "invoice", f: { internal_memo: "値引き" })
    assert_includes numbers_in(response.body), @doc_a.id
    assert_not_includes numbers_in(response.body), @doc_b.id

    get documents_path(kind: "invoice", f: { contact_person: "鈴木" })
    assert_includes numbers_in(response.body), @doc_b.id
    assert_not_includes numbers_in(response.body), @doc_a.id
  end

  test "filters by issue date range and amount" do
    get documents_path(kind: "invoice", f: { issue_from: "2026-11-10", issue_to: "2026-11-30" })
    assert_includes numbers_in(response.body), @doc_b.id
    assert_not_includes numbers_in(response.body), @doc_a.id

    get documents_path(kind: "invoice", f: { amount_min: 20000 })
    assert_not_includes numbers_in(response.body), @doc_a.id
  end

  test "filters by creator, delivery status and viewed" do
    @doc_a.update!(created_by: users(:one))
    @doc_a.document_deliveries.create!(tenant: @tenant, channel: "email", status: "sent", recipient: "a@example.co.jp", sent_at: Time.current)
    @doc_a.update!(public_viewed_at: Time.current)

    get documents_path(kind: "invoice", f: { created_by: users(:one).id })
    assert_includes numbers_in(response.body), @doc_a.id

    get documents_path(kind: "invoice", f: { created_by: "auto" })
    assert_not_includes numbers_in(response.body), @doc_a.id

    get documents_path(kind: "invoice", f: { delivery_status: "sent" })
    assert_includes numbers_in(response.body), @doc_a.id
    assert_not_includes numbers_in(response.body), @doc_b.id

    get documents_path(kind: "invoice", f: { delivery_status: "unsent" })
    assert_includes numbers_in(response.body), @doc_b.id
    assert_not_includes numbers_in(response.body), @doc_a.id

    get documents_path(kind: "invoice", f: { viewed: "viewed" })
    assert_includes numbers_in(response.body), @doc_a.id
    assert_not_includes numbers_in(response.body), @doc_b.id
  end

  test "public link view is recorded" do
    token = @doc_b.public_link_token
    assert_nil @doc_b.public_viewed_at

    get public_document_path(token)

    assert_response :success
    assert @doc_b.reload.public_viewed_at.present?
  end
end

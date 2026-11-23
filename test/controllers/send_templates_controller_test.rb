require "test_helper"

class SendTemplatesControllerTest < ActionDispatch::IntegrationTest
test "creates email and fax templates and lists them" do
sign_in_as(users(:one))

assert_difference("SendTemplate.count", 1) do
post send_templates_path, params: { send_template: {
channel: "email", name: "月末用", subject: "《帳票種別》をお送りします", body: "《取引先名》 様\n《帳票番号》です。"
}}
end
assert_difference("SendTemplate.count", 1) do
post send_templates_path, params: { send_template: {
channel: "fax", name: "FAX標準", body: "FAXで《帳票種別》をお送りします。"
}}
end

get send_templates_path
assert_response:success
assert_match "月末用", response.body
assert_match "FAX標準", response.body
end

test "sending mail with a template substitutes placeholders in subject and body" do
sign_in_as(users(:one))
template = tenants(:one).send_templates.create!(
channel: "email", name: "差し込み",
subject: "《帳票種別》（《帳票番号》）",
body: "《取引先名》 様\n合計は《合計金額》です。"
)
document = documents(:invoice_one)

post document_delivery_path(document), params: {
recipient_email: "billing@example.co.jp", email_template_id: template.id
}

assert_redirected_to document_path(document)
mail = ActionMailer::Base.deliveries.last
assert_equal "#{document.kind_label}（#{document.number}）", mail.subject
assert_match document.client.name, mail.text_part.body.to_s
assert_match "48,100円", mail.text_part.body.to_s
end

test "fax cover renders the chosen template body" do
sign_in_as(users(:one))
template = tenants(:one).send_templates.create!(
channel: "fax", name: "FAX用", body: "《取引先名》 御中\nFAXにて《帳票種別》をお送りします。"
)
document = documents(:invoice_one)

get fax_cover_document_path(document, send_template_id: template.id)

assert_response:success
assert_match "FAX送り状", response.body
assert_match "FAXにて#{document.kind_label}をお送りします", response.body
end

test "envelope renders the client address and honorific" do
sign_in_as(users(:one))
document = documents(:invoice_one)

get envelope_document_path(document)

assert_response:success
assert_match ERB::Util.html_escape(document.client.name), response.body
assert_match "御中", response.body
end
end

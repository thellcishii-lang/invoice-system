require "test_helper"

class Operator::OperatorDashboardTest < ActionDispatch::IntegrationTest
  setup do
    OperatorAccount.create!(email: "op@example.co.jp", password: "password123")
    @tenant = Tenant.create!(name: "テスト商事", billing_status: "active")
    @tenant.users.create!(name: "担当", email_address: "hq@test.example", password: "password123")
    SignupApplication.create!(
      company_name: "テスト商事", contact_name: "山田太郎", email: "yamada@test.example",
      status: "completed", tenant: @tenant, agreed_to_terms: true
    )
    SignupApplication.create!(
      company_name: "見込み建設", contact_name: "佐藤花", email: "sato@mikomi.example",
      status: "pending", agreed_to_terms: true, edition: "construction", billing_interval: "yearly"
    )
  end

  def sign_in_operator
    post operator_session_path, params: { email: "op@example.co.jp", password: "password123" }
  end

  test "dashboard requires operator login" do
    get operator_root_path
    assert_redirected_to new_operator_session_path
  end

  test "wrong password is rejected" do
    post operator_session_path, params: { email: "op@example.co.jp", password: "wrong" }
    assert_redirected_to new_operator_session_path
    get operator_root_path
    assert_redirected_to new_operator_session_path
  end

  test "dashboard lists tenants with contact and summary" do
    sign_in_operator
    get operator_root_path
    assert_response :success
    assert_includes response.body, "テスト商事"
    assert_includes response.body, "yamada@test.example"
    assert_includes response.body, "契約中"
    assert_includes response.body, "¥2,500"
    assert_includes response.body, "見込み建設"
  end

  test "yearly tenants count toward MRR at a twelfth of the yearly price" do
    Tenant.create!(name: "年払い工務店", billing_status: "active", billing_interval: "yearly", edition: "construction")
    sign_in_operator
    get operator_root_path
    # 月払い 2,500 + 年払い 25,000/12 ≒ 2,083 = 4,583
    assert_includes response.body, "¥4,583"
  end

  test "cancelled tenant shows 解約済" do
    @tenant.update!(billing_status: "cancelled", contract_ended_at: 1.day.ago)
    sign_in_operator
    get operator_root_path
    assert_includes response.body, "解約済"
  end

  test "operator can change password" do
    sign_in_operator
    patch operator_password_path, params: { current_password: "password123", password: "newpassword1", password_confirmation: "newpassword1" }
    assert_redirected_to operator_root_path
    delete operator_session_path
    post operator_session_path, params: { email: "op@example.co.jp", password: "newpassword1" }
    assert_redirected_to operator_root_path
  end
end

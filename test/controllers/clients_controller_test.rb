require "test_helper"

class ClientsControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when unauthenticated" do
    get clients_path

    assert_redirected_to new_session_path
  end

  test "index shows only own tenant clients" do
    sign_in_as(users(:one))

    get clients_path

    assert_response :success
    assert_match ERB::Util.html_escape(clients(:one).name), response.body
    assert_no_match ERB::Util.html_escape(clients(:two).name), response.body
  end

  test "creates a client for own tenant" do
    sign_in_as(users(:one))

    assert_difference("Client.count", 1) do
      post clients_path, params: { client: {
        name: "新規取引先株式会社", contact_person: "鈴木一郎", payment_terms: "月末締め・翌月末払い"
      } }
    end

    client = Client.order(:id).last
    assert_redirected_to client_path(client)
    assert_equal tenants(:one), client.tenant
    assert_equal "新規取引先株式会社", client.name
  end

  test "cannot show another tenant's client" do
    sign_in_as(users(:one))

    get client_path(clients(:two))

    assert_response :not_found
  end

  test "cannot edit another tenant's client" do
    sign_in_as(users(:one))

    get edit_client_path(clients(:two))

    assert_response :not_found
  end

  test "cannot update another tenant's client" do
    sign_in_as(users(:one))

    patch client_path(clients(:two)), params: { client: { name: "乗っ取り株式会社" } }

    assert_response :not_found
    assert_equal "有限会社テスト工務店", clients(:two).reload.name
  end

  test "cannot destroy another tenant's client" do
    sign_in_as(users(:one))

    assert_no_difference("Client.count") do
      delete client_path(clients(:two))
    end

    assert_response :not_found
    assert Client.exists?(clients(:two).id)
  end

  test "updates and destroys own client" do
    sign_in_as(users(:one))

    patch client_path(clients(:one)), params: { client: { name: "変更後の取引先" } }
    assert_redirected_to client_path(clients(:one))
    assert_equal "変更後の取引先", clients(:one).reload.name

    assert_difference("Client.count", -1) do
      delete client_path(clients(:one))
    end
    assert_redirected_to clients_path
  end
end

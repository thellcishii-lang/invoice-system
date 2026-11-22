require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "disabled user cannot sign in" do
    @user.update!(disabled: true)

    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(users(:one))

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end

  test "user of a suspended tenant cannot sign in" do
    @user.tenant.update!(billing_status: :suspended)

    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
    assert_match "停止中", flash[:alert]
  end

  test "user of a cancelled tenant cannot sign in" do
    @user.tenant.update!(billing_status: :cancelled, contract_ended_at: Time.current)

    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
    assert_match "終了している", flash[:alert]
  end

  test "existing session stops working when the tenant is suspended" do
    sign_in_as(users(:one))
    @user.tenant.update!(billing_status: :suspended)

    get root_path

    assert_redirected_to new_session_path
  end

  test "user of an active tenant can sign in" do
    @user.tenant.update!(billing_status: :active)

    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end
end

require "test_helper"

class PasswordSetupsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "edit renders the form with a valid token" do
    get password_setup_path(@user.password_setup_token)

    assert_response :success
    assert_match "パスワードの設定", response.body
  end

  test "update sets the password and redirects to login" do
    token = @user.password_setup_token

    patch password_setup_path(token), params: { password: "new-password-123", password_confirmation: "new-password-123" }

    assert_redirected_to new_session_path
    assert @user.reload.authenticate("new-password-123")
  end

  test "update with mismatched confirmation does not change the password" do
    token = @user.password_setup_token

    patch password_setup_path(token), params: { password: "new-password-123", password_confirmation: "different-123" }

    assert_redirected_to password_setup_path(token)
    assert_not @user.reload.authenticate("new-password-123")
  end

  test "edit with an invalid token redirects to login" do
    get password_setup_path("invalid-token")

    assert_redirected_to new_session_path
    assert_equal "パスワード設定リンクが無効か、期限切れです。", flash[:alert]
  end

  test "edit with an expired token redirects to login" do
    token = @user.password_setup_token

    travel 73.hours do
      get password_setup_path(token)

      assert_redirected_to new_session_path
    end
  end
end

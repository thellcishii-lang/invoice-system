require "application_system_test_case"

class LoginTest < ApplicationSystemTestCase
  test "login page renders with the email and password form" do
    visit new_session_path

    assert_selector "h1", text: "ログイン"
    assert_field "メールアドレス"
    assert_field "パスワード"
  end
end

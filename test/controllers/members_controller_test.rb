require "test_helper"

class MembersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @tenant = tenants(:one)
  end

  test "invites a member who sets their own password and logs in individually" do
    assert_difference "User.count", 1 do
      assert_emails 1 do
        post members_path, params: { member: { name: "経理 佐藤", email_address: "sato@example.co.jp" } }
      end
    end
    assert_redirected_to members_path

    member = User.find_by(email_address: "sato@example.co.jp")
    assert_nil member.password_set_at, "招待中はパスワード未設定"

    # 招待リンクから本人がパスワードを設定する
    patch password_setup_path(member.password_setup_token),
          params: { password: "sato-secret-1", password_confirmation: "sato-secret-1" }
    assert member.reload.password_set_at.present?

    # 個別ログインできる
    delete session_path
    post session_path, params: { email_address: "sato@example.co.jp", password: "sato-secret-1" }
    assert_redirected_to root_path
  end

  test "members are unlimited" do
    assert_difference "User.count", 7 do
      7.times do |i|
        post members_path, params: { member: { name: "member#{i}", email_address: "m#{i}@example.co.jp" } }
        assert_redirected_to members_path
      end
    end
  end

  test "disabling a member blocks login" do
    member = @tenant.users.create!(name: "退職者", email_address: "old@example.co.jp", password: "password-old")

    post disable_member_path(member)
    assert member.reload.disabled?

    delete session_path
    post session_path, params: { email_address: "old@example.co.jp", password: "password-old" }
    assert_redirected_to new_session_path
  end

  test "cannot disable yourself" do
    post disable_member_path(users(:one))
    assert_not users(:one).reload.disabled?
  end

  test "resends the invite email" do
    member = @tenant.users.create!(name: "招待中", email_address: "pending@example.co.jp", password: SecureRandom.hex(8))

    assert_emails 1 do
      post resend_invite_member_path(member)
    end
    assert_redirected_to members_path
  end
end

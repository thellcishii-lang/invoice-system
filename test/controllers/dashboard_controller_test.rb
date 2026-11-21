require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when unauthenticated" do
    get root_path

    assert_redirected_to new_session_path
  end

  test "shows dashboard with own tenant name when signed in" do
    sign_in_as(users(:one))

    get root_path

    assert_response :success
    assert_select "h1", "ダッシュボード"
    assert_match ERB::Util.html_escape(tenants(:one).name), response.body
    assert_no_match ERB::Util.html_escape(tenants(:two).name), response.body
  end
end

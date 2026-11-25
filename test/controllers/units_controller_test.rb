require "test_helper"

class UnitsControllerTest < ActionDispatch::IntegrationTest
  test "creates a unit via JSON for the quick-add popup" do
    sign_in_as(users(:one))

    assert_difference("Unit.count", 1) do
      post units_path, params: { unit: { name: "ケース" } }, as: :json
    end

    assert_response :created
    assert_equal "ケース", JSON.parse(response.body)["name"]
    assert_equal tenants(:one), Unit.order(:id).last.tenant
  end

  test "JSON create rejects a duplicate unit name" do
    sign_in_as(users(:one))
    tenants(:one).units.create!(name: "個")

    assert_no_difference("Unit.count") do
      post units_path, params: { unit: { name: "個" } }, as: :json
    end

    assert_response :unprocessable_entity
    assert JSON.parse(response.body)["errors"].any?
  end

  test "redirects to login when unauthenticated" do
    post units_path, params: { unit: { name: "個" } }, as: :json

    assert_redirected_to new_session_path
  end
end

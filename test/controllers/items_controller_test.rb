require "test_helper"

class ItemsControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when unauthenticated" do
    get items_path

    assert_redirected_to new_session_path
  end

  test "index shows only own tenant items" do
    sign_in_as(users(:one))

    get items_path

    assert_response :success
    assert_match ERB::Util.html_escape(items(:one).name), response.body
    assert_no_match ERB::Util.html_escape(items(:other_tenant).name), response.body
  end

  test "creates an item with an auto-assigned code" do
    sign_in_as(users(:one))

    assert_difference("Item.count", 1) do
      post items_path, params: { item: {
        name: "新規品目", unit_price: 1200, unit: "個", tax_rate: "reduced"
      } }
    end

    item = Item.order(:id).last
    assert_redirected_to item_path(item)
    assert_equal tenants(:one), item.tenant
    # fixture: tenant one already uses I000001, I000002
    assert_equal "I000003", item.code
    assert_equal "reduced", item.tax_rate
  end

  test "cannot show another tenant's item" do
    sign_in_as(users(:one))

    get item_path(items(:other_tenant))

    assert_response :not_found
  end

  test "cannot edit another tenant's item" do
    sign_in_as(users(:one))

    get edit_item_path(items(:other_tenant))

    assert_response :not_found
  end

  test "cannot update another tenant's item" do
    sign_in_as(users(:one))

    patch item_path(items(:other_tenant)), params: { item: { name: "乗っ取り品目" } }

    assert_response :not_found
    assert_equal "工事作業費", items(:other_tenant).reload.name
  end

  test "cannot destroy another tenant's item" do
    sign_in_as(users(:one))

    assert_no_difference("Item.count") do
      delete item_path(items(:other_tenant))
    end

    assert_response :not_found
    assert Item.exists?(items(:other_tenant).id)
  end

  test "updates own item without changing its code" do
    sign_in_as(users(:one))

    patch item_path(items(:one)), params: { item: { name: "変更後の品目", code: "I999999" } }

    assert_redirected_to item_path(items(:one))
    item = items(:one).reload
    assert_equal "変更後の品目", item.name
    assert_equal "I000001", item.code
  end

  test "destroys own item" do
    sign_in_as(users(:one))

    assert_difference("Item.count", -1) do
      delete item_path(items(:one))
    end
    assert_redirected_to items_path
  end
end

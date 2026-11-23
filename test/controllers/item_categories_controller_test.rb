require "test_helper"

class ItemCategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = tenants(:one)
  end

  test "creates a root category and a child category" do
    sign_in_as(users(:one))

    assert_difference("ItemCategory.count", 1) do
      post item_categories_path, params: { item_category: { name: "サービス", note: "月額もの" } }
    end
    root = ItemCategory.order(:id).last
    assert_nil root.parent_id
    assert_equal "月額もの", root.note

    assert_difference("ItemCategory.count", 1) do
      post item_categories_path, params: { item_category: { name: "保守", parent_id: root.id } }
    end
    child = ItemCategory.order(:id).last
    assert_equal root, child.parent
    assert_equal "サービス ＞ 保守", child.path_name
  end

  test "rejects a cycle when a category is moved under its own child" do
    sign_in_as(users(:one))
    root = @tenant.item_categories.create!(name: "親")
    child = @tenant.item_categories.create!(name: "子", parent: root)

    patch item_category_path(root), params: { item_category: { name: "親", parent_id: child.id } }

    assert_response :unprocessable_entity
    assert_nil root.reload.parent_id
  end

  test "destroy moves items to uncategorized and is blocked while children exist" do
    sign_in_as(users(:one))
    root = @tenant.item_categories.create!(name: "親")
    child = @tenant.item_categories.create!(name: "子", parent: root)
    item = items(:one)
    item.update!(item_category: child)

    delete item_category_path(root)
    assert_equal root, child.reload.parent, "子分類がある分類は削除できない"

    delete item_category_path(child)
    assert_nil item.reload.item_category_id, "削除した分類の品目は未分類になる"
  end

  test "items index filters by category including descendants, and by uncategorized" do
    sign_in_as(users(:one))
    root = @tenant.item_categories.create!(name: "サービス分類")
    child = @tenant.item_categories.create!(name: "保守分類", parent: root)
    items(:one).update!(item_category: child)
    items(:two).update!(item_category: root)

    get items_path(category: root.id)
    assert_response :success
    assert_match ERB::Util.html_escape(items(:one).name), response.body
    assert_match ERB::Util.html_escape(items(:two).name), response.body

    get items_path(category: child.id)
    assert_match ERB::Util.html_escape(items(:one).name), response.body
    assert_no_match ERB::Util.html_escape(items(:two).name), response.body

    get items_path(category: "none")
    assert_no_match ERB::Util.html_escape(items(:one).name), response.body
    assert_no_match ERB::Util.html_escape(items(:two).name), response.body
  end

  test "item can be assigned to a category from the item form params" do
    sign_in_as(users(:one))
    category = @tenant.item_categories.create!(name: "物販")

    patch item_path(items(:one)), params: { item: { item_category_id: category.id } }

    assert_equal category, items(:one).reload.item_category
  end
end

require "test_helper"

class ItemCategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = tenants(:one)
  end

  test "creates a root category and a child category" do
    sign_in_as(users(:one))

    assert_difference("ItemCategory.count", 1) do
      post item_categories_path, params: { item_category: { name: "サービス" } }
    end
    root = ItemCategory.order(:id).last
    assert_nil root.parent_id

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

  test "segments are auto-assigned per parent and build hierarchical codes" do
    root_a = @tenant.item_categories.create!(name: "A")
    root_b = @tenant.item_categories.create!(name: "B")
    child = @tenant.item_categories.create!(name: "A-1", parent: root_a)
    grandchild = @tenant.item_categories.create!(name: "A-1-1", parent: child)
    great = @tenant.item_categories.create!(name: "A-1-1-1", parent: grandchild)

    assert_equal "A001", root_a.full_code
    assert_equal "A002", root_b.full_code
    assert_equal "A001-001", child.full_code
    assert_equal "A001-001001001", great.full_code

    item = items(:one)
    item.update!(item_category: great)
    assert_equal "001", item.segment
    assert_equal "A001-001001001001", item.part_number
  end

  test "item segments are numbered within their category and never reused" do
    category = @tenant.item_categories.create!(name: "部品")
    first = @tenant.items.create!(name: "ネジA", unit_price: 10, tax_rate: "standard", item_category: category)
    second = @tenant.items.create!(name: "ネジB", unit_price: 20, tax_rate: "standard", item_category: category)
    assert_equal "001", first.segment
    assert_equal "002", second.segment
    assert_equal "#{category.full_code}002", second.part_number

    first.destroy!
    third = @tenant.items.create!(name: "ネジC", unit_price: 30, tax_rate: "standard", item_category: category)
    assert_equal "003", third.segment, "削除した品目の番号は再利用しない"

    other = @tenant.item_categories.create!(name: "材料")
    second.update!(item_category: other)
    assert_equal "001", second.reload.segment, "分類を変えたら新しい分類で採番し直す"
    assert_equal "#{other.full_code}001", second.part_number
  end

  test "segments are never reused after deletion" do
    first = @tenant.item_categories.create!(name: "最初")
    assert_equal "001", first.segment
    first.destroy!

    second = @tenant.item_categories.create!(name: "次")
    assert_equal "002", second.segment
  end

  test "moving a category to another parent reassigns its segment there" do
    root_a = @tenant.item_categories.create!(name: "A")
    root_b = @tenant.item_categories.create!(name: "B")
    @tenant.item_categories.create!(name: "B-1", parent: root_b)
    mover = @tenant.item_categories.create!(name: "移動", parent: root_a)
    assert_equal "001", mover.segment

    mover.update!(parent: root_b)

    assert_equal "002", mover.reload.segment
    assert_equal "A002-002", mover.full_code
  end

  test "uncategorized item part number is just the serial" do
    assert_equal items(:one).code.delete_prefix("I"), items(:one).part_number
  end

  test "item can be assigned to a category from the item form params" do
    sign_in_as(users(:one))
    category = @tenant.item_categories.create!(name: "物販")

    patch item_path(items(:one)), params: { item: { item_category_id: category.id } }

    assert_equal category, items(:one).reload.item_category
  end
end

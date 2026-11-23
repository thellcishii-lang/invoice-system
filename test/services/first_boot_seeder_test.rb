require "test_helper"

class FirstBootSeederTest < ActiveSupport::TestCase
  # Fixtures load tenants, so the empty-database case first wipes every
  # table (child tables first; delete_all skips callbacks and FK order
  # matters). The surrounding test transaction restores the fixtures.
  def wipe_all_tables
    DocumentLine.delete_all
    Payment.delete_all
    DocumentDelivery.delete_all
    RecurringDocument.delete_all
    Document.delete_all
    DocumentSequence.delete_all
    SignupApplication.delete_all
    Client.delete_all
    Item.delete_all
    User.delete_all
    Tenant.delete_all
  end

  test "seeds the database when no tenant exists yet" do
    wipe_all_tables
    assert_equal 0, Tenant.count

    assert FirstBootSeeder.call

    assert Tenant.exists?
    assert User.exists?(email_address: "admin@example.co.jp")
    assert Client.exists?(name: "株式会社サンプル商事")
  end

  test "does nothing when tenants already exist" do
    assert Tenant.exists?

    assert_no_difference -> { Tenant.count } do
      assert_not FirstBootSeeder.call
    end
  end

  test "running it twice only seeds once" do
    wipe_all_tables
    assert FirstBootSeeder.call

    assert_no_difference -> { Tenant.count } do
      assert_not FirstBootSeeder.call
    end
  end
end

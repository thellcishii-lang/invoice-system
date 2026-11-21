require "test_helper"

class ClientTest < ActiveSupport::TestCase
  test "requires a name" do
    client = tenants(:one).clients.build(name: "")

    assert_not client.valid?
    assert_includes client.errors[:name], "can't be blank"
  end

  test "active scope excludes archived clients" do
    active_clients = tenants(:one).clients.active

    assert_includes active_clients, clients(:one)
    assert_not_includes active_clients, clients(:archived_one)
  end
end

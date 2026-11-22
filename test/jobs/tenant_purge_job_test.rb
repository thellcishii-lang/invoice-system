require "test_helper"

class TenantPurgeJobTest < ActiveJob::TestCase
  test "purges a tenant cancelled more than 30 days ago with all its data" do
    tenant = build_tenant_with_data(billing_status: :cancelled, contract_ended_at: 31.days.ago)

    assert_difference "Tenant.count", -1 do
      TenantPurgeJob.perform_now
    end

    assert_equal 0, User.where(tenant_id: tenant.id).count
    assert_equal 0, Client.where(tenant_id: tenant.id).count
    assert_equal 0, Item.where(tenant_id: tenant.id).count
    assert_equal 0, Document.where(tenant_id: tenant.id).count
    assert_equal 0, SignupApplication.where(tenant_id: tenant.id).count
  end

  test "keeps a tenant cancelled within 30 days" do
    tenant = build_tenant_with_data(billing_status: :cancelled, contract_ended_at: 29.days.ago)

    assert_no_difference "Tenant.count" do
      TenantPurgeJob.perform_now
    end
    assert Tenant.exists?(tenant.id)
  end

  test "keeps suspended and active tenants even with an old contract end date" do
    build_tenant_with_data(billing_status: :suspended, contract_ended_at: 60.days.ago)
    build_tenant_with_data(billing_status: :active, contract_ended_at: 60.days.ago)

    assert_no_difference "Tenant.count" do
      TenantPurgeJob.perform_now
    end
  end

  private
    def build_tenant_with_data(billing_status:, contract_ended_at:)
      tenant = Tenant.create!(
        name: "削除テスト株式会社", billing_status: billing_status, contract_ended_at: contract_ended_at
      )
      tenant.users.create!(name: "担当者", email_address: "purge-#{SecureRandom.hex(4)}@example.co.jp", password: "password")
      client = tenant.clients.create!(name: "取引先株式会社")
      item = tenant.items.create!(name: "品目", unit_price: 1000)
      document = tenant.documents.build(kind: "invoice", client: client, issue_date: Date.current)
      document.document_lines.build(item: item, name: "品目", quantity: 1, unit_price: 1000, tax_rate: "standard")
      document.save!
      SignupApplication.create!(
        company_name: tenant.name, contact_name: "担当者", email: "apply-#{SecureRandom.hex(4)}@example.co.jp",
        agreed_to_terms: true, status: "completed", tenant: tenant
      )
      tenant
    end
end

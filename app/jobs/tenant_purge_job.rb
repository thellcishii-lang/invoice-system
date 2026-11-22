# 解約から30日が経過したテナントのデータを完全に削除するジョブ。
# 本番では Solid Queue の recurring（config/recurring.yml の tenant_purge、
# 毎日6時）に登録済み。
# 手動実行: bin/rails runner "TenantPurgeJob.perform_now"
class TenantPurgeJob < ApplicationJob
  queue_as :default

  def perform
    Tenant.billing_cancelled
          .where(contract_ended_at: ..30.days.ago)
          .find_each(&:purge!)
  end
end

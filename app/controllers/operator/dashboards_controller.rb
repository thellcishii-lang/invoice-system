module Operator
  class DashboardsController < BaseController
    MONTHLY_PRICE = 2_500
    YEARLY_PRICE = 25_000

    def show
      @tenants = Tenant.includes(:users).order(created_at: :desc)
      @applications_by_tenant = SignupApplication.where.not(tenant_id: nil).index_by(&:tenant_id)
      @pending_applications = SignupApplication.where(status: "pending").order(created_at: :desc)

      @active_count = @tenants.count { |t| display_status(t) == :active }
      @suspended_count = @tenants.count { |t| display_status(t) == :suspended }
      @cancelled_count = @tenants.count { |t| display_status(t) == :cancelled }
      # MRR（税別）: 月払いは月額そのまま、年払いは年額を12で割った月換算
      @mrr = @tenants.sum do |t|
        next 0 unless display_status(t) == :active

        t.yearly? ? (YEARLY_PRICE / 12.0).round : MONTHLY_PRICE
      end
      @signups_this_month = SignupApplication.where(created_at: Time.current.beginning_of_month..).count
    end

    private

    def display_status(tenant)
      return :cancelled if tenant.contract_ended_at.present? || tenant.billing_cancelled?
      return :suspended if tenant.billing_suspended?
      return :none if tenant.billing_none?

      :active
    end
    helper_method :display_status
  end
end

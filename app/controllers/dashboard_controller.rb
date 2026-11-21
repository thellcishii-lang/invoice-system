class DashboardController < ApplicationController
  def index
    @tenant = Current.tenant

    this_month = Date.current.beginning_of_month..Date.current.end_of_month
    @monthly_billed = @tenant.documents.invoice.issued.where(issue_date: this_month).sum(:total)

    unpaid = @tenant.documents.unpaid_invoices.includes(:payments)
    @unpaid_balance = unpaid.sum(&:balance)
    @overdue_count = unpaid.count { |document| document.overdue? }
  end
end

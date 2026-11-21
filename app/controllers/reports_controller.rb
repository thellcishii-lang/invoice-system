class ReportsController < ApplicationController
  def show
    tenant = Current.tenant
    first_month = Date.current.beginning_of_month << 11
    last_day = Date.current.end_of_month

    billed_by_month = tenant.documents.invoice.issued
      .where(issue_date: first_month..last_day)
      .group_by { |document| document.issue_date.beginning_of_month }
      .transform_values { |documents| documents.sum(&:total) }
    received_by_month = tenant.payments
      .where(paid_on: first_month..last_day)
      .group_by { |payment| payment.paid_on.beginning_of_month }
      .transform_values { |payments| payments.sum(&:amount) }

    @rows = (0..11).map do |i|
      month = first_month >> i
      { month: month, billed: billed_by_month[month] || 0, received: received_by_month[month] || 0 }
    end.reverse

    unpaid = tenant.documents.unpaid_invoices.includes(:payments)
    @unpaid_balance = unpaid.sum(&:balance)
    @overdue_count = unpaid.count { |document| document.overdue? }
  end
end

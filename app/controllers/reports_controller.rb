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

    # 月別の請求書一覧（入金済み・未入金が分かるように）
    @month = parse_month(params[:month])
    month_range = @month..@month.end_of_month
    @invoices = tenant.documents.invoice.issued
      .where(issue_date: month_range)
      .includes(:client, :payments)
      .order(:issue_date, :id)
    @month_billed = @invoices.sum(&:total)
    @month_received = @invoices.sum(&:received_amount)
    @month_unpaid = @invoices.sum { |document| [ document.balance, 0 ].max }
  end

  private
    def parse_month(value)
      return Date.current.beginning_of_month if value.blank?

      Date.strptime(value, "%Y-%m").beginning_of_month
    rescue ArgumentError
      Date.current.beginning_of_month
    end
end

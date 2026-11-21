class UnpaidInvoicesController < ApplicationController
  def index
    @today = Date.current
    @invoices = Current.tenant.documents.unpaid_invoices.includes(:client, :payments)
    @total_balance = @invoices.sum(&:balance)
  end
end

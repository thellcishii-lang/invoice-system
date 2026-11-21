class DashboardController < ApplicationController
  def index
    @tenant = Current.tenant
  end
end

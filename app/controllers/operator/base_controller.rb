module Operator
  class BaseController < ActionController::Base
    layout "operator"

    helper_method :current_operator

    before_action :require_operator

    def current_operator
      @current_operator ||= OperatorAccount.find_by(id: session[:operator_id])
    end

    private

    def require_operator
      return if current_operator

      redirect_to new_operator_session_path, alert: "運営者ログインが必要です。"
    end
  end
end

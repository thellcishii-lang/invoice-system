module Operator
  class SessionsController < BaseController
    skip_before_action :require_operator, only: %i[ new create ]

    def new
      OperatorAccount.bootstrap!
    end

    def create
      OperatorAccount.bootstrap!
      operator = OperatorAccount.find_by(email: params[:email].to_s.strip)
      if operator&.authenticate(params[:password].to_s)
        session[:operator_id] = operator.id
        redirect_to operator_root_path, notice: "ログインしました。"
      else
        redirect_to new_operator_session_path, alert: "メールアドレスまたはパスワードが違います。"
      end
    end

    def destroy
      session.delete(:operator_id)
      redirect_to new_operator_session_path, notice: "ログアウトしました。"
    end
  end
end

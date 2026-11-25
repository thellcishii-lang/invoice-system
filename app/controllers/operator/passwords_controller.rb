module Operator
  class PasswordsController < BaseController
    def edit
    end

    def update
      if !current_operator.authenticate(params[:current_password].to_s)
        redirect_to edit_operator_password_path, alert: "現在のパスワードが違います。"
      elsif params[:password].to_s.length < 8
        redirect_to edit_operator_password_path, alert: "パスワードは8文字以上にしてください。"
      elsif params[:password] != params[:password_confirmation]
        redirect_to edit_operator_password_path, alert: "確認用パスワードが一致しません。"
      else
        current_operator.update!(password: params[:password])
        redirect_to operator_root_path, notice: "パスワードを変更しました。"
      end
    end
  end
end

module Operator
  class TenantsController < BaseController
    # HTMLメールの ON/OFF 切り替え（販売先ダッシュボードのボタンから）。
    def update
      tenant = Tenant.find(params[:id])
      tenant.update!(html_mail_enabled: params.dig(:tenant, :html_mail_enabled) == "true")
      redirect_to operator_root_path,
                  notice: "#{tenant.name} のHTMLメールを #{tenant.html_mail_enabled? ? 'ON' : 'OFF'} にしました。"
    end
  end
end

class SettingsController < ApplicationController
  def show
    @tenant = Current.tenant
  end

  def update
    @tenant = Current.tenant

    if @tenant.update(tenant_params)
      redirect_to setting_path, notice: "設定を保存しました。"
    else
      render :show, status: :unprocessable_entity
    end
  end

  private
    def tenant_params
      params.expect(tenant: %i[ name invoice_registration_number postal_code address phone email
                                document_number_prefix tax_rounding tax_display ])
    end
end

class SettingsController < ApplicationController
  def show
    @tenant = Current.tenant
  end

  def update
    @tenant = Current.tenant

    unless @tenant.update(tenant_params)
      return render :show, status: :unprocessable_entity
    end

    if params.dig(:tenant, :remove_seal) == "1"
      @tenant.remove_seal
    elsif params.dig(:tenant, :seal_image).present?
      unless @tenant.attach_seal(params[:tenant][:seal_image])
        return render :show, status: :unprocessable_entity
      end
    end

    redirect_to setting_path, notice: "設定を保存しました。"
  end

  private
    def tenant_params
      params.expect(tenant: %i[ name invoice_registration_number postal_code address phone email bank_details
                                document_number_prefix tax_rounding tax_display ])
    end
end

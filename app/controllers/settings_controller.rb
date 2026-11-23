class SettingsController < ApplicationController
  def show
    @tenant = Current.tenant
  end

  def update
    @tenant = Current.tenant

    unless @tenant.update(tenant_params)
      return render :show, status: :unprocessable_entity
    end

    if params.dig(:tenant, :document_color_reset) == "1"
      @tenant.update(document_color: nil)
    end

    if params.dig(:tenant, :remove_seal) == "1"
      @tenant.remove_seal
    elsif params.dig(:tenant, :seal_image).present?
      unless @tenant.attach_seal(params[:tenant][:seal_image])
        return render :show, status: :unprocessable_entity
      end
    end

    if params.dig(:tenant, :remove_logo) == "1"
      @tenant.remove_logo
    elsif params.dig(:tenant, :logo_image).present?
      unless @tenant.attach_logo(params[:tenant][:logo_image])
        return render :show, status: :unprocessable_entity
      end
    end

    redirect_to setting_path, notice: "設定を保存しました。"
  end

  private
    def tenant_params
      params.expect(tenant: %i[ name edition invoice_registration_number postal_code address phone email
                                bank_name bank_branch bank_account_type bank_account_number bank_account_holder
                                logo_placement logo_alignment
                                document_number_prefix tax_rounding tax_display
                                document_color document_striped document_pattern ])
    end
end

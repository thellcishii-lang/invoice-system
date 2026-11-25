class SettingsController < ApplicationController
  def show
    @tenant = Current.tenant
  end

  def test_smtp
    @tenant = Current.tenant
    unless @tenant.smtp_configured?
      return redirect_to setting_path, alert: "SMTP設定が未入力です。先に保存してください。"
    end

    SmtpTestMailer.test_email(@tenant).deliver_now
    redirect_to setting_path, notice: "テストメールを #{@tenant.email} に送信しました。"
  rescue StandardError => e
    redirect_to setting_path, alert: "テスト送信に失敗しました：#{e.message}"
  end

  def update
    @tenant = Current.tenant

    permitted = begin
      tenant_params
    rescue ActionController::ParameterMissing
      # チェックボックスだけの送信など、対象キーが無い場合は空として扱う
      ActionController::Parameters.new
    end
    # パスワードが空欄なら、保存済みのものを保持する
    permitted.delete(:smtp_password) if permitted[:smtp_password].blank?

    unless @tenant.update(permitted)
      return render :show, status: :unprocessable_entity
    end

    if params.dig(:tenant, :clear_smtp) == "1"
      @tenant.clear_smtp!
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
                                document_color document_striped document_pattern
                                envelope_size envelope_direction envelope_sender envelope_logo
                                smtp_host smtp_port smtp_username smtp_password smtp_from_address ])
    end
end

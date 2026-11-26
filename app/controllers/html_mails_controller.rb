class HtmlMailsController < ApplicationController
  # HTMLメールが OFF のテナントには機能自体を見せない（入口も画面も出さない）。
  before_action :require_html_mail_enabled

  def show
    @tenant = Current.tenant
    @mail_form = {}
  end

  def create
    @tenant = Current.tenant
    @mail_form = params.require(:html_mail).permit(:recipient_email, :subject, :body)
    recipient = @mail_form[:recipient_email].to_s.strip
    subject = @mail_form[:subject].to_s.strip
    body = @mail_form[:body].to_s

    if recipient.blank? || subject.blank? || body.blank?
      flash.now[:alert] = "宛先・件名・本文をすべて入力してください。"
      render :show, status: :unprocessable_entity
      return
    end

    begin
      HtmlMailer.business_email(tenant: @tenant, recipient_email: recipient, subject: subject, body: body).deliver_now
      redirect_to html_mail_path, notice: "HTMLメールを送信しました。"
    rescue => e
      Rails.logger.error("HTMLメール送信失敗: #{e.class}: #{e.message}")
      flash.now[:alert] = "送信に失敗しました。宛先をご確認のうえ、時間をおいて再度お試しください。"
      render :show, status: :unprocessable_entity
    end
  end

  private

  def require_html_mail_enabled
    redirect_to root_path unless Current.tenant&.html_mail_enabled?
  end
end

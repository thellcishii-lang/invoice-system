class DocumentDeliveriesController < ApplicationController
  before_action :set_document, only: %i[ new create ]

  # 送信履歴（全体）: 送信できたか後から確認でき、送信不可のものは再送できる
  def index
    @deliveries = Current.tenant.document_deliveries.recent
                    .includes(document: :client).limit(200)
    @deliveries = @deliveries.where(status: "failed") if params[:status] == "failed"
  end

  # 送信確認画面（送信方法と送信先は取引先の登録を初期表示し、編集できる）
  def new
    @channel = "email"
    @recipient_email = @document.client.email
    @recipient_fax = @document.client.fax_number
    load_templates
  end

  def create
    channel = params[:channel].to_s
    if channel == "fax"
      recipient = params[:recipient_fax].to_s.strip
      delivery = @document.attempt_delivery!(channel: "fax", recipient: recipient)
      if delivery.sent?
        redirect_to @document, notice: "#{@document.kind_label}をFAXで送信しました。"
      else
        redirect_to @document, alert: "FAX送信できませんでした: #{delivery.error_message}"
      end
    else
      recipient_email = params[:recipient_email].to_s
      template = Current.tenant.send_templates.where(channel: "email").find_by(id: params[:email_template_id])
      @document.deliver_by_email!(recipient_email, send_template: template)
      redirect_to @document, notice: "#{@document.kind_label}をメールで送信しました。"
    end
  rescue ArgumentError => e
    @channel = channel
    @recipient_email = params[:recipient_email].to_s
    @recipient_fax = params[:recipient_fax].to_s
    load_templates
    flash.now[:alert] = e.message.presence || "送信先を入力してください。"
    render :new, status: :unprocessable_entity
  end

  # 送信不可だったものを手動で再送する（宛先は取引先の現在の登録を使う）
  def resend
    delivery = Current.tenant.document_deliveries.find(params.expect(:id))
    document = delivery.document
    recipient = delivery.channel == "fax" ? document.client.fax_number : document.client.email
    recipient = delivery.recipient_display if recipient.blank?

    result = document.attempt_delivery!(channel: delivery.channel, recipient: recipient)
    if result.sent?
      redirect_back fallback_location: document_deliveries_path,
                    notice: "#{document.kind_label}（#{document.number}）を#{delivery.channel_label}で再送しました。"
    else
      redirect_back fallback_location: document_deliveries_path,
                    alert: "再送できませんでした: #{result.error_message}"
    end
  end

  private
    def load_templates
      @email_templates = Current.tenant.send_templates.where(channel: "email").order(:id)
      @fax_templates = Current.tenant.send_templates.where(channel: "fax").order(:id)
    end

    def set_document
      @document = Current.tenant.documents.find(params.expect(:document_id))
    end
end

class DocumentDeliveriesController < ApplicationController
  before_action :set_document

  # 送信確認画面（送信先は取引先のメールアドレスを初期表示し、編集できる）
  def new
    @recipient_email = @document.client.email
  end

  def create
    recipient_email = params[:recipient_email].to_s
    @document.deliver_by_email!(recipient_email)
    redirect_to @document, notice: "#{@document.kind_label}をメールで送信しました。"
  rescue ArgumentError
    @recipient_email = recipient_email
    flash.now[:alert] = "送信先メールアドレスを入力してください。"
    render :new, status: :unprocessable_entity
  end

  private
    def set_document
      @document = Current.tenant.documents.find(params.expect(:document_id))
    end
end

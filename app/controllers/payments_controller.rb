class PaymentsController < ApplicationController
  before_action :set_document
  before_action :set_payment, only: %i[ edit update destroy ]

  def create
    @payment = @document.payments.build(payment_params.merge(tenant: Current.tenant))

    if @payment.save
      redirect_to @document, notice: "入金を登録しました。"
    else
      # 未保存の入金が詳細画面の一覧・合計に混ざらないよう読み直す
      @document.reload
      render "documents/show", status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @payment.update(payment_params)
      redirect_to @document, notice: "入金を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @payment.destroy!
    redirect_to @document, notice: "入金を削除しました。"
  end

  private
    def set_document
      @document = Current.tenant.documents.find(params.expect(:document_id))
    end

    def set_payment
      @payment = @document.payments.find(params.expect(:id))
    end

    def payment_params
      params.expect(payment: [ :amount, :paid_on, :method, :note ])
    end
end

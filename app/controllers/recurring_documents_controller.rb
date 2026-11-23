class RecurringDocumentsController < ApplicationController
  before_action :set_recurring_document, only: %i[ edit update destroy ]

  def index
    @recurring_documents = Current.tenant.recurring_documents
      .includes(:client, :template_document).order(:next_run_date, :id)
  end

  def new
    @recurring_document = Current.tenant.recurring_documents.build(day_of_month: 1)
    if (template = find_template(params[:template_document_id]))
      @recurring_document.template_document = template
      @recurring_document.client = template.client
      @recurring_document.day_of_month = [ template.issue_date.day, 28 ].min
    end
    load_form_data
  end

  def create
    @recurring_document = Current.tenant.recurring_documents.build(recurring_document_params.except(:template_document_id))
    template = find_template(recurring_document_params[:template_document_id])
    @recurring_document.template_document = template
    @recurring_document.client = template&.client

    if @recurring_document.save
      redirect_to recurring_documents_path, notice: "定期請求を登録しました。次回実行日は #{@recurring_document.next_run_date} です。"
    else
      load_form_data
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_form_data
  end

  def update
    if @recurring_document.update(recurring_document_params.except(:template_document_id))
      redirect_to recurring_documents_path, notice: "定期請求を更新しました。"
    else
      load_form_data
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @recurring_document.destroy!
    redirect_to recurring_documents_path, notice: "定期請求を削除しました。"
  end

  private
    def set_recurring_document
      @recurring_document = Current.tenant.recurring_documents.find(params.expect(:id))
    end

    def find_template(id)
      return if id.blank?

      Current.tenant.documents.where(kind: "invoice").find_by(id: id)
    end

    def load_form_data
      @templates = Current.tenant.documents.where(kind: "invoice")
        .includes(:client).order(issue_date: :desc, id: :desc)
    end

    def recurring_document_params
      params.expect(recurring_document: [ :template_document_id, :day_of_month, :send_method, :send_template_id, :active ])
    end
end

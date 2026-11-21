class DocumentsController < ApplicationController
  before_action :set_document, only: %i[ show edit update destroy print convert ]

  def index
    @kind = params[:kind] if Document::KINDS.include?(params[:kind])
    @documents = Current.tenant.documents.includes(:client).order(issue_date: :desc, id: :desc)
    @documents = @documents.where(kind: @kind) if @kind
  end

  def show
  end

  def new
    kind = Document::KINDS.include?(params[:kind]) ? params[:kind] : "estimate"
    @document = Current.tenant.documents.build(kind: kind, issue_date: Date.current)
    @document.document_lines.build(quantity: 1, unit_price: 0)
    load_form_data
  end

  def create
    @document = Current.tenant.documents.build(document_params)

    if @document.save
      @document.recalculate_totals!
      redirect_to @document, notice: "#{@document.kind_label}を作成しました。"
    else
      load_form_data
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_form_data
  end

  def update
    # 帳票番号は種別と発行年月で採番済みのため、種別は変更しない
    if @document.update(document_params.except("kind"))
      @document.recalculate_totals!
      redirect_to @document, notice: "#{@document.kind_label}を更新しました。"
    else
      load_form_data
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    kind_label = @document.kind_label
    @document.destroy!
    redirect_to documents_path(kind: @document.kind), notice: "#{kind_label}を削除しました。"
  end

  # 印刷用表示（ブラウザ印刷でPDF化する）
  def print
    render layout: "print"
  end

  def convert
    converted = @document.convert_to(params.expect(:target_kind))
    redirect_to converted, notice: "#{converted.kind_label}に変換しました。"
  rescue ArgumentError
    redirect_to @document, alert: "その変換はできません。"
  end

  private
    def set_document
      @document = Current.tenant.documents.find(params.expect(:id))
    end

    def load_form_data
      @clients = Current.tenant.clients.order(:name)
      @items = Current.tenant.items.active.order(:code)
    end

    def document_params
      params.expect(document: [ :kind, :client_id, :issue_date, :due_date, :title, :status, :notes,
        { document_lines_attributes: [ %i[ id item_id name quantity unit unit_price tax_rate _destroy ] ] } ])
    end
end

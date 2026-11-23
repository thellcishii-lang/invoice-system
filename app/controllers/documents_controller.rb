class DocumentsController < ApplicationController
  before_action :set_document, only: %i[ show edit update destroy print construction_print envelope fax_cover convert duplicate ]

  def index
    @kind = params[:kind] if Document::KINDS.include?(params[:kind])
    @documents = Current.tenant.documents.includes(:client).order(issue_date: :desc, id: :desc)
    @documents = @documents.where(kind: @kind) if @kind
  end

  def show
  end

  def new
    kind = Document::KINDS.include?(params[:kind]) ? params[:kind] : "estimate"
    defaults = { kind: kind, issue_date: Date.current }
    # 見積書だけ、有効期限の初期値として発行日+30日を入れる
    defaults[:due_date] = Date.current + 30.days if kind == "estimate"
    @document = Current.tenant.documents.build(defaults)
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

  # 建築様式の印刷（横書き）: 表紙 → 内訳集計（中分類ごとの合計）→ 中分類ごとの明細。
  # 中分類は品目の分類（ItemCategory）。分類のない明細は「その他」にまとめる。
  def construction_print
    lines = @document.document_lines.includes(item: { item_category: :parent })
    grouped = lines.group_by { |line| line.item&.item_category }
    @groups = grouped.sort_by { |category, _| category ? [ 0, category.full_code ] : [ 1, "" ] }
    render layout: "print"
  end

  # 封筒の宛名印刷（長形3号・横向き）
  def envelope
    render layout: "print"
  end

  # FAX送り状の印刷（テンプレート指定があれば差し込む）
  def fax_cover
    @send_template = Current.tenant.send_templates.where(channel: "fax").find_by(id: params[:send_template_id])
    render layout: "print"
  end

  def convert
    converted = @document.convert_to(params.expect(:target_kind))
    redirect_to converted, notice: "#{converted.kind_label}に変換しました。"
  rescue ArgumentError
    redirect_to @document, alert: "その変換はできません。"
  end

  def duplicate
    copy = @document.duplicate!
    redirect_to edit_document_path(copy), notice: "複写しました。内容を確認して保存してください。"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @document, alert: e.record.errors.full_messages.to_sentence
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

class DocumentsController < ApplicationController
  before_action :set_document, only: %i[ show edit update destroy print construction_print envelope fax_cover convert duplicate save_as_template ]

  def index
    @kind = params[:kind] if Document::KINDS.include?(params[:kind])
    @documents = Current.tenant.documents.includes(:client, :created_by, :document_lines).order(issue_date: :desc, id: :desc)
    @documents = @documents.where(kind: @kind) if @kind
    apply_filters
    @clients = Current.tenant.clients.order(:name)
    @members = Current.tenant.users.order(:id)
  end

  def show
  end

  def new
    if params[:template_id].present?
      # テンプレートから作成：件名・備考・明細を引き継ぎ、取引先はこの画面で選ぶ
      template = Current.tenant.document_templates.find(params[:template_id])
      @document = template.build_document
    else
      kind = Document::KINDS.include?(params[:kind]) ? params[:kind] : "estimate"
      defaults = { kind: kind, issue_date: Date.current }
      # 見積書だけ、有効期限の初期値として発行日+30日を入れる
      defaults[:due_date] = Date.current + 30.days if kind == "estimate"
      @document = Current.tenant.documents.build(defaults)
      @document.document_lines.build(quantity: 1, unit_price: 0)
    end
    load_form_data
  end

  # この帳票の内容（件名・備考・明細）をテンプレートとして保存する
  def save_as_template
    template = DocumentTemplate.from_document(@document)

    if template.save
      redirect_to edit_document_template_path(template), notice: "テンプレートとして保存しました。名前を確認してください。"
    else
      redirect_to @document, alert: "テンプレートの保存に失敗しました。"
    end
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
      @units = Unit.names_for(Current.tenant)
    end

    def document_params
      params.expect(document: [ :kind, :client_id, :issue_date, :due_date, :title, :status, :notes, :internal_memo,
        { document_lines_attributes: [ %i[ id item_id name quantity unit unit_price cost_unit_price tax_rate _destroy ] ] } ])
    end

    # 一覧のフィルター（freee の絞り込み項目に相当するもの）
    def apply_filters
      @f = params[:f].is_a?(ActionController::Parameters) ? params[:f] : {}
      @filter_active = @f.values.any?(&:present?)
      return unless @filter_active

      like = ->(value) { "%#{ActiveRecord::Base.sanitize_sql_like(value.to_s)}%" }

      @documents = @documents.where(client_id: @f[:client_id]) if @f[:client_id].present?
      @documents = @documents.where("documents.title ILIKE ?", like.call(@f[:title])) if @f[:title].present?
      @documents = @documents.where("documents.number ILIKE ?", like.call(@f[:number])) if @f[:number].present?
      @documents = @documents.where("documents.notes ILIKE ?", like.call(@f[:notes])) if @f[:notes].present?
      @documents = @documents.where("documents.internal_memo ILIKE ?", like.call(@f[:internal_memo])) if @f[:internal_memo].present?

      if @f[:contact_person].present?
        @documents = @documents.joins(:client).where("clients.contact_person ILIKE ?", like.call(@f[:contact_person]))
      end
      if @f[:line_name].present?
        @documents = @documents.joins(:document_lines).where("document_lines.name ILIKE ?", like.call(@f[:line_name])).distinct
      end

      @documents = @documents.where("documents.total >= ?", @f[:amount_min].to_i) if @f[:amount_min].present?
      @documents = @documents.where("documents.total <= ?", @f[:amount_max].to_i) if @f[:amount_max].present?

      if (from = filter_date(@f[:issue_from]))
        @documents = @documents.where(issue_date: from..)
      end
      if (to = filter_date(@f[:issue_to]))
        @documents = @documents.where(issue_date: ..to)
      end
      if (from = filter_date(@f[:due_from]))
        @documents = @documents.where(due_date: from..)
      end
      if (to = filter_date(@f[:due_to]))
        @documents = @documents.where(due_date: ..to)
      end

      @documents = @documents.where(status: @f[:status]) if Document.statuses.key?(@f[:status])
      if @kind == "invoice" && Document.payment_statuses.key?(@f[:payment_status])
        @documents = @documents.where(payment_status: @f[:payment_status])
      end

      case @f[:created_by]
      when "auto"
        @documents = @documents.where(created_by_id: nil)
      when /\A\d+\z/
        @documents = @documents.where(created_by_id: @f[:created_by].to_i)
      end

      sent_ids = DocumentDelivery.where(status: "sent").select(:document_id)
      case @f[:delivery_status]
      when "sent" then @documents = @documents.where(id: sent_ids)
      when "unsent" then @documents = @documents.where.not(id: sent_ids)
      when "failed" then @documents = @documents.where(id: DocumentDelivery.where(status: "failed").select(:document_id))
      end

      pending_ids = ScheduledDelivery.where(status: "pending").select(:document_id)
      case @f[:scheduled]
      when "yes" then @documents = @documents.where(id: pending_ids)
      when "no" then @documents = @documents.where.not(id: pending_ids)
      end

      parent_ids = Document.where.not(converted_from_id: nil).select(:converted_from_id)
      case @f[:related]
      when "yes" then @documents = @documents.where("documents.converted_from_id IS NOT NULL OR documents.id IN (?)", parent_ids)
      when "no" then @documents = @documents.where(converted_from_id: nil).where.not(id: parent_ids)
      end

      case @f[:viewed]
      when "viewed" then @documents = @documents.where.not(public_viewed_at: nil)
      when "unviewed" then @documents = @documents.where(public_viewed_at: nil)
      end
    end

    def filter_date(value)
      return nil if value.blank?

      Date.parse(value.to_s)
    rescue Date::Error
      nil
    end
end

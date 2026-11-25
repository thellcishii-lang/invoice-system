class DocumentTemplatesController < ApplicationController
  before_action :set_document_template, only: %i[ edit update destroy ]
  before_action :set_kind
  before_action :load_items, only: %i[ new create edit update ]

  def index
    @document_templates = Current.tenant.document_templates
                                     .where(kind: @kind)
                                     .includes(:document_template_lines)
                                     .order(:id)
    if params[:q].present?
      like = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%"
      @document_templates = @document_templates.where("document_templates.name ILIKE :q OR document_templates.title ILIKE :q", q: like)
    end
  end

  def new
    @document_template = Current.tenant.document_templates.build(kind: @kind)
    @document_template.document_template_lines.build(quantity: 1, unit_price: 0)
  end

  def create
    @document_template = Current.tenant.document_templates.build(document_template_params.merge(kind: @kind))

    if @document_template.save
      redirect_to document_templates_path(kind: @kind), notice: "テンプレートを登録しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @document_template.update(document_template_params)
      redirect_to document_templates_path(kind: @kind), notice: "テンプレートを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @document_template.destroy!
    redirect_to document_templates_path(kind: @kind), notice: "テンプレートを削除しました。", status: :see_other
  end

  private
    def set_document_template
      @document_template = Current.tenant.document_templates.find(params.expect(:id))
    end

    def set_kind
      @kind = if @document_template
        @document_template.kind
      elsif Document::KINDS.include?(params[:kind])
        params[:kind]
      else
        "estimate"
      end
    end

    def load_items
      @items = Current.tenant.items.active.order(:code)
      @units = Unit.names_for(Current.tenant)
    end

    def document_template_params
      params.expect(document_template: [
        :name, :title, :notes,
        { document_template_lines_attributes: [ %i[ id item_id name quantity unit unit_price cost_unit_price tax_rate _destroy ] ] }
      ])
    end
end

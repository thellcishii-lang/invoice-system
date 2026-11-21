class ItemsController < ApplicationController
  before_action :set_item, only: %i[ show edit update destroy ]

  def index
    @items = Current.tenant.items.order(:code)
  end

  def show
  end

  def new
    @item = Current.tenant.items.build
  end

  def create
    @item = Current.tenant.items.build(item_params)

    if @item.save
      redirect_to @item, notice: "品目を登録しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @item.update(item_params)
      redirect_to @item, notice: "品目を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @item.destroy!
    redirect_to items_path, notice: "品目を削除しました。"
  end

  private
    def set_item
      @item = Current.tenant.items.find(params.expect(:id))
    end

    def item_params
      # 品目コードは自動採番のため変更不可（strong parameters に含めない）
      params.expect(item: %i[ name unit_price unit tax_rate description active ])
    end
end

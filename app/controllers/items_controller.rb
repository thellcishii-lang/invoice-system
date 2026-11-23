class ItemsController < ApplicationController
  before_action :set_item, only: %i[ show edit update destroy ]

  def index
    @items = Current.tenant.items.includes(:item_category).order(:code)

    # 分類ツリー（全体像）: 親子マップと、配下込みの品目数を用意する
    all_categories = Current.tenant.item_categories.ordered
    @children_by_parent = all_categories.group_by(&:parent_id)
    direct_counts = Current.tenant.items.group(:item_category_id).count
    @total_counts = {}
    count_walk = lambda do |category|
      total = direct_counts[category.id].to_i
      (@children_by_parent[category.id] || []).each { |child| total += count_walk.call(child) }
      @total_counts[category.id] = total
    end
    (@children_by_parent[nil] || []).each { |root| count_walk.call(root) }
    @uncategorized_count = direct_counts[nil].to_i
    @all_count = Current.tenant.items.count

    case params[:category]
    when "none"
      @selected = :none
      @items = @items.where(item_category_id: nil)
    when /\A\d+\z/
      @selected_category = Current.tenant.item_categories.find_by(id: params[:category])
      if @selected_category
        @selected = @selected_category.id
        @items = @items.where(item_category_id: @selected_category.subtree_ids)
      end
    end
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
      params.expect(item: %i[ name unit_price unit tax_rate description active item_category_id ])
    end
end

class ItemCategoriesController < ApplicationController
  before_action :set_item_category, only: %i[ edit update destroy ]
  before_action :load_parent_options, only: %i[ new create edit update ]

  def new
    @item_category = Current.tenant.item_categories.build(parent_id: params[:parent_id])
  end

  def create
    @item_category = Current.tenant.item_categories.build(item_category_params)

    if @item_category.save
      redirect_to items_path(category: @item_category.id), notice: "分類を登録しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @item_category.update(item_category_params)
      redirect_to items_path(category: @item_category.id), notice: "分類を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @item_category.destroy
      redirect_to items_path, notice: "分類を削除しました。配下の品目は「未分類」に移りました。", status: :see_other
    else
      redirect_to items_path, alert: "子分類があるため削除できません。先に子分類を削除または移動してください。", status: :see_other
    end
  end

  private
    def set_item_category
      @item_category = Current.tenant.item_categories.find(params.expect(:id))
    end

    # 親の選択肢: 編集中の分類とその配下は選べない（循環防止）
    def load_parent_options
      excluded = @item_category&.persisted? ? @item_category.subtree_ids : []
      @parent_options = ItemCategory.tree_options(Current.tenant).reject { |(_, id)| excluded.include?(id) }
    end

    def item_category_params
      params.expect(item_category: %i[ name parent_id position ])
    end
end

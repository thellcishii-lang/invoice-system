class UnitsController < ApplicationController
  # 明細行の「単位を追加」ポップアップからの登録（JSON）と通常フォーム用の作成口。
  def create
    @unit = Current.tenant.units.build(unit_params)

    if @unit.save
      respond_to do |format|
        format.html { redirect_back fallback_location: root_path, notice: "単位を追加しました。" }
        format.json { render json: { name: @unit.name }, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: root_path, alert: @unit.errors.full_messages.join("／") }
        format.json { render json: { errors: @unit.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  private

    def unit_params
      params.expect(unit: %i[ name ])
    end
end

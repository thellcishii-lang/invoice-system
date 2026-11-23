# リンク共有の公開画面。署名付きトークン（目的・有効期限つき）でのみ
# アクセスでき、印刷画面と同じ帳票を表示する。
class PublicDocumentsController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    @document = Document.find_by_public_link_token(params.expect(:token))
    raise ActiveRecord::RecordNotFound if @document.blank?

    # 送付先が開いたことを記録する（フィルターの「送付先の閲覧」で使う）
    @document.update_column(:public_viewed_at, Time.current) if @document.public_viewed_at.nil?

    @public_view = true
    render "documents/print", layout: "print"
  end
end

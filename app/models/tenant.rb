class Tenant < ApplicationRecord
  MAX_MEMBERS = 5

  # 端数処理: floor=切り捨て / round=四捨五入 / ceil=切り上げ
  enum :tax_rounding, { floor: "floor", round: "round", ceil: "ceil" }, validate: true
  # 税表示: exclusive=税抜 / inclusive=税込
  enum :tax_display, { exclusive: "exclusive", inclusive: "inclusive" }, validate: true
  # SaaS利用料の課金状態: none=未契約 / active=契約中 / suspended=停止中 / cancelled=解約済み
  # （billing_active? のように prefix 付きで使う）
  enum :billing_status, { none: "none", active: "active", suspended: "suspended", cancelled: "cancelled" },
       prefix: :billing, validate: true

  has_many :users, dependent: :restrict_with_error
  has_many :clients, dependent: :restrict_with_error
  has_many :items, dependent: :restrict_with_error
  has_many :documents, dependent: :restrict_with_error
  has_many :document_sequences, dependent: :restrict_with_error
  has_many :document_deliveries, dependent: :restrict_with_error
  has_many :recurring_documents, dependent: :restrict_with_error
  has_many :payments, dependent: :restrict_with_error
  has_many :signup_applications, dependent: :restrict_with_error

  validates :name, presence: true

  # 印鑑画像はDBにBase64で持つ。Renderのディスクは再デプロイで消えるため、
  # ファイル保存（Active Storage + ローカル）では本番で印鑑が消えてしまう。
  SEAL_CONTENT_TYPES = %w[image/png image/jpeg].freeze
  SEAL_MAX_BYTES = 1.megabyte

  # アップロードされた印鑑画像を保存する。成功したら true、形式・サイズが
  # 不正ならエラーを追加して false。
  def attach_seal(uploaded_file)
    unless SEAL_CONTENT_TYPES.include?(uploaded_file.content_type)
      errors.add(:seal_image, "はPNGまたはJPEGの画像にしてください")
      return false
    end
    if uploaded_file.size > SEAL_MAX_BYTES
      errors.add(:seal_image, "は1MB以下にしてください")
      return false
    end

    self.seal_image_data = Base64.strict_encode64(uploaded_file.read)
    self.seal_image_content_type = uploaded_file.content_type
    save
  end

  def remove_seal
    update(seal_image_data: nil, seal_image_content_type: nil)
  end

  def seal_image?
    seal_image_data.present?
  end

  # 請求書に印字する振込先。構造化した口座情報があれば組み立て、
  # なければ自由記述（旧フィールド）にフォールバックする。
  def bank_details_text
    if bank_name.present? || bank_account_number.present?
      lines = [ [ bank_name, bank_branch, bank_account_type, bank_account_number ].compact_blank.join(" ") ]
      lines << "口座名義：#{bank_account_holder}" if bank_account_holder.present?
      lines.join("\n")
    else
      bank_details
    end
  end

  # 印刷ビューでそのまま <img src> に使える data URI
  def seal_image_data_uri
    return nil unless seal_image?

    "data:#{seal_image_content_type};base64,#{seal_image_data}"
  end

  def member_limit_reached?
    users.count >= MAX_MEMBERS
  end

  # 課金停止・解約済みのテナントはログインできない
  def billing_blocked?
    billing_suspended? || billing_cancelled?
  end

  def billing_blocked_message
    if billing_cancelled?
      "ご契約が終了しているため、ログインできません。"
    else
      "ご契約が停止中のため、ログインできません。お支払い状況をご確認ください。"
    end
  end

  # 指定日が属する月に作成した請求書の数（発行日ベース）
  def invoice_count_for(date)
    documents.invoice.where(issue_date: date.beginning_of_month..date.end_of_month).count
  end

  # その月の請求書作成上限に達しているか（上限が NULL なら無制限）
  def invoice_limit_reached?(date = Date.current)
    return false if monthly_invoice_limit.nil?

    invoice_count_for(date) >= monthly_invoice_limit
  end

  # 解約から30日経過したテナントのデータを全て削除する。
  # 関連は restrict_with_error のため、依存の深いものから順に消す。
  # 帳票を消すと明細・送信履歴・入金は帳票側の dependent: :destroy で消える。
  def purge!
    transaction do
      signup_applications.destroy_all
      payments.destroy_all
      document_deliveries.destroy_all
      recurring_documents.destroy_all
      documents.destroy_all
      document_sequences.destroy_all
      clients.destroy_all
      items.destroy_all
      users.destroy_all
      destroy!
    end
  end
end

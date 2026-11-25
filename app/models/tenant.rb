class Tenant < ApplicationRecord

  # 端数処理: floor=切り捨て / round=四捨五入 / ceil=切り上げ
  enum :tax_rounding, { floor: "floor", round: "round", ceil: "ceil" }, validate: true
  # 税表示: exclusive=税抜 / inclusive=税込
  enum :tax_display, { exclusive: "exclusive", inclusive: "inclusive" }, validate: true
  # SaaS利用料の課金状態: none=未契約 / active=契約中 / suspended=停止中 / cancelled=解約済み
  # （billing_active? のように prefix 付きで使う）
  enum :billing_status, { none: "none", active: "active", suspended: "suspended", cancelled: "cancelled" },
       prefix: :billing, validate: true
  # 契約プランの支払い区分（申込から引き継ぐ。運営ダッシュボードの集計に使う）
  enum :billing_interval, { monthly: "monthly", yearly: "yearly" }, validate: true

  has_many :users, dependent: :restrict_with_error
  has_many :clients, dependent: :restrict_with_error
  has_many :units, dependent: :restrict_with_error
  has_many :items, dependent: :restrict_with_error
  has_many :item_categories, dependent: :restrict_with_error
  has_many :send_templates, dependent: :restrict_with_error
  has_many :document_templates, dependent: :restrict_with_error
  has_many :scheduled_deliveries, dependent: :destroy

  # 製品エディション: 申込時に決まる（一般 / 建築）。建築は見積書が建築様式になる。
  EDITIONS = %w[ general construction ].freeze
  EDITION_LABELS = { "general" => "一般", "construction" => "建築" }.freeze

  validates :edition, inclusion: { in: EDITIONS }

  def construction?
    edition == "construction"
  end

  # --- テナント自身の SMTP 設定（帳票メールをテナントのアドレスから送る） ---
  # パスワードは平文で保存せず、secret_key_base から導いた鍵で暗号化する。
  def smtp_configured?
    smtp_host.present? && smtp_username.present? &&
      smtp_password_ciphertext.present? && smtp_from_address.present?
  end

  def smtp_password
    return nil if smtp_password_ciphertext.blank?

    self.class.smtp_encryptor.decrypt_and_verify(smtp_password_ciphertext)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  def smtp_password=(value)
    self.smtp_password_ciphertext = value.present? ? self.class.smtp_encryptor.encrypt_and_sign(value) : nil
  end

  def smtp_settings
    settings = {
      address: smtp_host,
      port: smtp_port,
      user_name: smtp_username,
      password: smtp_password,
      authentication: :plain
    }
    if smtp_port == 465
      settings[:ssl] = true
    else
      settings[:enable_starttls_auto] = true
    end
    settings
  end

  def clear_smtp!
    update!(smtp_host: nil, smtp_username: nil, smtp_password_ciphertext: nil, smtp_from_address: nil)
  end

  def self.smtp_encryptor
    key = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key("tenant-smtp-password", 32)
    ActiveSupport::MessageEncryptor.new(key)
  end

  DOCUMENT_PATTERNS = %w[ none dots diagonal grid ].freeze
  DOCUMENT_PATTERN_LABELS = { "none" => "なし", "dots" => "ドット", "diagonal" => "斜めストライプ", "grid" => "格子" }.freeze

  # 封筒印刷: [幅mm, 高さmm]（横向きに置いた寸法）
  ENVELOPE_SIZES = { "chou3" => [ 235, 120 ], "chou4" => [ 205, 90 ] }.freeze
  ENVELOPE_SIZE_LABELS = { "chou3" => "長形3号（120×235mm）", "chou4" => "長形4号（90×205mm）" }.freeze
  ENVELOPE_DIRECTION_LABELS = { "horizontal" => "横向き", "vertical" => "縦向き" }.freeze

  def envelope_dimensions(size = envelope_size)
    ENVELOPE_SIZES.fetch(size, ENVELOPE_SIZES["chou4"])
  end

  validates :document_pattern, inclusion: { in: DOCUMENT_PATTERNS }
  validates :document_color, format: { with: /\A#[0-9a-fA-F]{6}\z/ }, allow_blank: true
  has_many :documents, dependent: :restrict_with_error
  has_many :document_sequences, dependent: :restrict_with_error
  has_many :document_deliveries, dependent: :restrict_with_error
  has_many :recurring_documents, dependent: :restrict_with_error
  has_many :payments, dependent: :restrict_with_error
  has_many :signup_applications, dependent: :restrict_with_error

  validates :name, presence: true

  # 印鑑・ロゴ画像はDBにBase64で持つ。Renderのディスクは再デプロイで消えるため、
  # ファイル保存（Active Storage + ローカル）では本番で画像が消えてしまう。
  # サイズ制限で弾く代わりに、大きな画像は自動で縮小して保存する
  # （利用者に「○MB以下」と言っても伝わらないため）。上限は不正防止の天井だけ。
  IMAGE_CONTENT_TYPES = %w[image/png image/jpeg].freeze
  IMAGE_MAX_BYTES = 10.megabytes
  SEAL_RESIZE_LIMIT = [ 400, 400 ].freeze
  LOGO_RESIZE_LIMIT = [ 1200, 400 ].freeze

  # アップロードされた印鑑画像を縮小して保存する。成功したら true、
  # 形式が不正ならエラーを追加して false。
  def attach_seal(uploaded_file)
    store_image(uploaded_file, :seal_image, SEAL_RESIZE_LIMIT) do |data, content_type|
      self.seal_image_data = data
      self.seal_image_content_type = content_type
    end
  end

  def remove_seal
    update(seal_image_data: nil, seal_image_content_type: nil)
  end

  def seal_image?
    seal_image_data.present?
  end

  LOGO_PLACEMENTS = %w[top bottom].freeze
  LOGO_ALIGNMENTS = %w[left center right].freeze

  def attach_logo(uploaded_file)
    store_image(uploaded_file, :logo_image, LOGO_RESIZE_LIMIT) do |data, content_type|
      self.logo_image_data = data
      self.logo_image_content_type = content_type
    end
  end

  def remove_logo
    update(logo_image_data: nil, logo_image_content_type: nil)
  end

  def logo_image?
    logo_image_data.present?
  end

  def logo_image_data_uri
    return nil unless logo_image?

    "data:#{logo_image_content_type};base64,#{logo_image_data}"
  end

  def logo_placement_value
    LOGO_PLACEMENTS.include?(logo_placement) ? logo_placement : "top"
  end

  def logo_alignment_value
    LOGO_ALIGNMENTS.include?(logo_alignment) ? logo_alignment : "left"
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

  private

  # 画像を検証し、大きければ resize_to_limit で縮小してから Base64 で渡す。
  # libvips が無い環境（CI等）では縮小せずそのまま保存する。本番（Docker）には
  # libvips が入っているので、必ず縮小される。
  def store_image(uploaded_file, attribute, resize_limit)
    unless IMAGE_CONTENT_TYPES.include?(uploaded_file.content_type)
      errors.add(attribute, "はPNGまたはJPEGの画像にしてください")
      return false
    end
    if uploaded_file.size > IMAGE_MAX_BYTES
      errors.add(attribute, "が大きすぎます")
      return false
    end

    bytes = shrink_image(uploaded_file, resize_limit)
    return false if bytes.nil?

    yield Base64.strict_encode64(bytes), uploaded_file.content_type
    save
  rescue => e
    Rails.logger.error("image store failed: #{e.class}: #{e.message}")
    errors.add(attribute, "を読み込めませんでした")
    false
  end

  def shrink_image(uploaded_file, resize_limit)
    require "image_processing/vips"
    path = uploaded_file.tempfile ? uploaded_file.tempfile.path : uploaded_file.path
    processed = ImageProcessing::Vips.source(path).resize_to_limit(resize_limit[0], resize_limit[1]).call
    File.binread(processed.path)
  rescue LoadError
    uploaded_file.rewind
    uploaded_file.read
  end

  public

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

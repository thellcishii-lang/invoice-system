class Unit < ApplicationRecord
  # 明細行の単位マスタ（テナントごと）。明細の単位そのものは文字列で保存され、
  # このマスタは入力時の選択肢を提供する。
  DEFAULT_NAMES = %w[個 式 セット 枚 本 台 件 回 人 時間 日 月].freeze

  belongs_to :tenant

  validates :name, presence: true, uniqueness: { scope: :tenant_id }

  # フォーム表示用の単位名一覧。まだ何も登録がなければ標準の単位を初期登録する。
  def self.names_for(tenant)
    seed_defaults(tenant) if tenant.units.none?
    tenant.units.order(:id).pluck(:name)
  end

  def self.seed_defaults(tenant)
    DEFAULT_NAMES.each { |name| tenant.units.find_or_create_by!(name: name) }
  end
end

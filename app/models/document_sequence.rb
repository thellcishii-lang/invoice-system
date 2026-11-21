class DocumentSequence < ApplicationRecord
  belongs_to :tenant

  validates :kind, presence: true
  validates :year_month, presence: true

  # テナント × 種別 × 年月（YYYYMM）の連番を採番する。
  # カウンタ行をロックして直列化するため、同時作成でも重複しない。
  # カウンタは増える一方なので、帳票を削除しても番号は再利用されない。
  def self.next_value(tenant:, kind:, issue_date:)
    sequence = find_or_create_for(tenant, kind, issue_date.strftime("%Y%m"))

    value = nil
    sequence.with_lock do
      sequence.increment!(:last_number)
      value = sequence.last_number
    end
    value
  end

  def self.find_or_create_for(tenant, kind, year_month)
    find_by!(tenant: tenant, kind: kind, year_month: year_month)
  rescue ActiveRecord::RecordNotFound
    begin
      create!(tenant: tenant, kind: kind, year_month: year_month)
    rescue ActiveRecord::RecordNotUnique
      find_by!(tenant: tenant, kind: kind, year_month: year_month)
    end
  end
  private_class_method :find_or_create_for
end

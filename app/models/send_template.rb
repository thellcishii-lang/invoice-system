class SendTemplate < ApplicationRecord
  include ActiveSupport::NumberHelper

  # 送り状の雛形。メール用とFAX用があり、それぞれ何個でも保存できる。
  # 本文・件名には《取引先名》のような差し込み項目が使える。
  CHANNELS = %w[ email fax ].freeze
  CHANNEL_LABELS = { "email" => "メール", "fax" => "FAX" }.freeze

  belongs_to :tenant
  has_many :recurring_documents, dependent: :nullify

  validates :channel, inclusion: { in: CHANNELS }
  validates :name, presence: true
  validates :body, presence: true

  def channel_label
    CHANNEL_LABELS[channel]
  end

  def render_subject(document)
    substitute(subject, document)
  end

  def render_body(document)
    substitute(body, document)
  end

  private
    def substitute(text, document)
      return "" if text.blank?

      placeholder_values(document).reduce(text.to_s) do |result, (token, value)|
        result.gsub(token, value)
      end
    end

    def placeholder_values(document)
      {
        "《取引先名》" => document.client.name.to_s,
        "《帳票種別》" => document.kind_label,
        "《帳票番号》" => document.number.to_s,
        "《件名》" => document.title.to_s,
        "《合計金額》" => "#{number_to_delimited(document.total)}円",
        "《発行日》" => document.issue_date.strftime("%Y年%m月%d日"),
        "《支払期限》" => document.due_date ? document.due_date.strftime("%Y年%m月%d日") : "",
        "《自社名》" => document.tenant.name.to_s
      }
    end
end

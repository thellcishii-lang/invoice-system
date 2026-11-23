class ScheduledDelivery < ApplicationRecord
  # 予約配信: 帳票を指定日時にメール/FAXで送る予約。
  # 時刻が来たら ScheduledDeliveriesJob が実行し、結果（送信済み/送信不可）が残る。
  CHANNELS = %w[ email fax ].freeze
  CHANNEL_LABELS = { "email" => "メール", "fax" => "FAX" }.freeze
  STATUSES = %w[ pending sent failed cancelled ].freeze
  STATUS_LABELS = { "pending" => "送信予定", "sent" => "送信済み", "failed" => "送信不可", "cancelled" => "取消済み" }.freeze

  belongs_to :tenant
  belongs_to :document
  belongs_to :send_template, optional: true

  validates :channel, inclusion: { in: CHANNELS }
  validates :status, inclusion: { in: STATUSES }
  validates :recipient, presence: true
  validates :scheduled_at, presence: true

  scope :due, -> { where(status: "pending").where(scheduled_at: ..Time.current) }

  def channel_label
    CHANNEL_LABELS[channel]
  end

  def status_label
    STATUS_LABELS[status]
  end

  def pending?
    status == "pending"
  end

  # 予約を実行する。送信の成否は DocumentDelivery にも記録される。
  def execute!
    return unless pending?

    delivery = document.attempt_delivery!(channel: channel, recipient: recipient, send_template: send_template)
    if delivery.sent?
      update!(status: "sent", sent_at: delivery.sent_at, error_message: nil)
    else
      update!(status: "failed", error_message: delivery.error_message)
    end
  end

  def cancel!
    update!(status: "cancelled") if pending?
  end
end

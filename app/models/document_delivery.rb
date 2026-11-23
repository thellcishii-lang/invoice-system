class DocumentDelivery < ApplicationRecord
  CHANNELS = %w[ email fax ].freeze
  CHANNEL_LABELS = { "email" => "メール", "fax" => "FAX" }.freeze
  STATUSES = %w[ sent failed ].freeze

  belongs_to :tenant
  belongs_to :document

  scope :recent, -> { order(created_at: :desc) }

  validates :channel, inclusion: { in: CHANNELS }
  validates :status, inclusion: { in: STATUSES }
  validates :recipient, presence: true
  validates :sent_at, presence: true, if: :sent?
  validate :document_must_belong_to_tenant

  def channel_label
    CHANNEL_LABELS[channel]
  end

  def sent?
    status == "sent"
  end

  def failed?
    status == "failed"
  end

  # 表示用の宛先（旧データは recipient_email にしか無い）
  def recipient_display
    recipient.presence || recipient_email
  end

  private
    def document_must_belong_to_tenant
      return if document.blank? || tenant.blank?
      return if document.tenant_id == tenant_id

      errors.add(:document, "は自社の帳票ではありません")
    end
end

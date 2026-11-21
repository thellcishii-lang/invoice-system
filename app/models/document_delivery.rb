class DocumentDelivery < ApplicationRecord
  CHANNELS = %w[ email ].freeze
  CHANNEL_LABELS = { "email" => "メール" }.freeze

  belongs_to :tenant
  belongs_to :document

  validates :channel, inclusion: { in: CHANNELS }
  validates :recipient_email, presence: true
  validates :sent_at, presence: true
  validate :document_must_belong_to_tenant

  def channel_label
    CHANNEL_LABELS[channel]
  end

  private
    def document_must_belong_to_tenant
      return if document.blank? || tenant.blank?
      return if document.tenant_id == tenant_id

      errors.add(:document, "は自社の帳票ではありません")
    end
end

class ScheduledDeliveriesController < ApplicationController
  before_action :set_document, only: %i[ create ]
  before_action :set_scheduled_delivery, only: %i[ cancel ]

  # 予約配信の一覧（送信予定 → 履歴の順）
  def index
    @upcoming = Current.tenant.scheduled_deliveries.where(status: "pending")
                              .includes(document: :client).order(scheduled_at: :asc).limit(100)
    @history = Current.tenant.scheduled_deliveries.where.not(status: "pending")
                             .includes(document: :client).order(scheduled_at: :desc).limit(100)
  end

  def create
    attrs = scheduled_delivery_params
    channel = attrs[:channel].presence_in(ScheduledDelivery::CHANNELS) || "email"
    recipient = channel == "fax" ? attrs[:fax_recipient] : attrs[:email_recipient]
    template = find_template(attrs[:send_template_id], channel)

    @scheduled_delivery = @document.scheduled_deliveries.build(
      tenant: Current.tenant, channel: channel, recipient: recipient.to_s.strip,
      scheduled_at: attrs[:scheduled_at], send_template: template
    )

    if @scheduled_delivery.save
      redirect_to @document, notice: "予約配信を登録しました（#{@scheduled_delivery.scheduled_at.strftime('%Y/%m/%d %H:%M')} に#{@scheduled_delivery.channel_label}で送信）。"
    else
      redirect_to @document, alert: "予約配信を登録できませんでした: #{@scheduled_delivery.errors.full_messages.join('、')}"
    end
  end

  def cancel
    @scheduled_delivery.cancel!
    redirect_back fallback_location: scheduled_deliveries_path, notice: "予約配信を取り消しました。"
  end

  private
    def set_document
      @document = Current.tenant.documents.find(params[:document_id])
    end

    def set_scheduled_delivery
      @scheduled_delivery = Current.tenant.scheduled_deliveries.find(params[:id])
    end

    def find_template(id, channel)
      return nil if id.blank?

      Current.tenant.send_templates.where(channel: channel).find_by(id: id)
    end

    def scheduled_delivery_params
      params.expect(scheduled_delivery: [ :channel, :email_recipient, :fax_recipient, :scheduled_at, :send_template_id ])
    end
end

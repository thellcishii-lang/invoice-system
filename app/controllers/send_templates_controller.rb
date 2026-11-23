class SendTemplatesController < ApplicationController
  before_action :set_send_template, only: %i[ edit update destroy ]

  def index
    @channel = %w[ email fax ].include?(params[:channel]) ? params[:channel] : nil
    @send_templates = Current.tenant.send_templates.order(:channel, :id)
    @send_templates = @send_templates.where(channel: @channel) if @channel
  end

  def new
    @send_template = Current.tenant.send_templates.build(channel: params[:channel] == "fax" ? "fax" : "email")
    @channel = @send_template.channel
  end

  def create
    @send_template = Current.tenant.send_templates.build(send_template_params)

    if @send_template.save
      redirect_to send_templates_path(channel: @send_template.channel), notice: "送り状テンプレートを登録しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @send_template.update(send_template_params)
      redirect_to send_templates_path(channel: @send_template.channel), notice: "送り状テンプレートを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @send_template.destroy!
    redirect_to send_templates_path(channel: @channel), notice: "送り状テンプレートを削除しました。", status: :see_other
  end

  private
    def set_send_template
      @send_template = Current.tenant.send_templates.find(params.expect(:id))
      @channel = @send_template.channel
    end

    def send_template_params
      params.expect(send_template: %i[ channel name subject body ])
    end
end

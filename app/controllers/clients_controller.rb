class ClientsController < ApplicationController
  before_action :set_client, only: %i[ show edit update destroy ]

  def index
    @clients = Current.tenant.clients.order(:id)
  end

  def show
  end

  def new
    @client = Current.tenant.clients.build
  end

  def create
    @client = Current.tenant.clients.build(client_params)

    if @client.save
      redirect_to @client, notice: "取引先を登録しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @client.update(client_params)
      redirect_to @client, notice: "取引先を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @client.destroy!
    redirect_to clients_path, notice: "取引先を削除しました。"
  end

  private
    def set_client
      @client = Current.tenant.clients.find(params.expect(:id))
    end

    def client_params
      params.expect(client: %i[ name name_kana postal_code address phone email
                                contact_person payment_terms registration_number archived ])
    end
end

class MembersController < ApplicationController
  before_action :set_member, only: %i[ resend_invite disable enable ]

  def index
    @members = Current.tenant.users.order(:id)
  end

  def new
    @member = Current.tenant.users.build
  end

  # メンバーを招待する。パスワードは本人が招待メールのリンクから設定する
  # （個別ログイン方式。管理者がパスワードを決めることはしない）。
  def create
    @member = Current.tenant.users.build(member_params)
    # 本人が設定するまで誰も知らないランダム値で仮登録する
    @member.password = SecureRandom.hex(24)

    if @member.save
      MemberMailer.invite(user: @member, token: @member.password_setup_token).deliver_now
      redirect_to members_path, notice: "#{@member.name} さんに招待メールを送りました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def resend_invite
    MemberMailer.invite(user: @member, token: @member.password_setup_token).deliver_now
    redirect_to members_path, notice: "#{@member.name} さんに招待メールを再送しました。"
  end

  def disable
    if @member == Current.user
      return redirect_to members_path, alert: "自分自身は無効化できません。"
    end

    @member.update!(disabled: true)
    redirect_to members_path, notice: "#{@member.name} さんを無効化しました。"
  end

  def enable
    @member.update!(disabled: false)
    redirect_to members_path, notice: "#{@member.name} さんを有効化しました。"
  end

  private
    def set_member
      @member = Current.tenant.users.find(params.expect(:id))
    end

    def member_params
      params.expect(member: %i[ name email_address ])
    end
end

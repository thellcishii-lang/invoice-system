# 定期請求の自動作成ジョブ。毎日1回実行する想定で、実行日になった
# スケジュールごとにテンプレートから請求書を作成する（自動送信つきの
# スケジュールは取引先へメール送信まで行う）。
#
# 本番では Solid Queue の recurring（config/recurring.yml の
# recurring_documents、毎日6時）に登録済み。
# 手動実行: bin/rails runner "RecurringDocumentsJob.perform_now"
# 日付を指定する場合: RecurringDocumentsJob.perform_now(Date.new(2026, 12, 1))
class RecurringDocumentsJob < ApplicationJob
  queue_as :default

  def perform(today = Date.current)
    RecurringDocument.due(today).find_each do |schedule|
      schedule.run!(today)
    end
  end
end

# FAX送信の窓口。送信サービス（インターファクス等）が決まったら、
# このクラスの中身だけを差し替える。呼び出し側（Document#attempt_delivery!）は
# 成否を送信履歴に記録するので、ここは例外で結果を返せばよい。
#
# 実送信には帳票PDFの生成が必要（サービス決定時にあわせて実装する）。
# 現状は未設定として扱い、送信履歴に「送信不可」で残る。
class FaxSender
  class NotConfigured < StandardError; end

  def self.configured?
    ENV["FAX_API_KEY"].present?
  end

  def self.deliver!(document:, fax_number:)
    raise ArgumentError, "FAX番号がありません" if fax_number.blank?
    raise NotConfigured, "FAX送信サービスが未設定です（送信サービスを選ぶと送れるようになります）" unless configured?

    # サービス決定後に実装: 帳票PDFを生成し、FAX送信APIへ渡す
    raise NotConfigured, "FAX送信サービスが未設定です（送信サービスを選ぶと送れるようになります）"
  end
end

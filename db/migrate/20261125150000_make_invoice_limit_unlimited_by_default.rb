class MakeInvoiceLimitUnlimitedByDefault < ActiveRecord::Migration[8.1]
  def change
    change_column_default :tenants, :monthly_invoice_limit, from: 100, to: nil

    reversible do |dir|
      # 請求書も無制限にする（2026-11-25決定）。既存テナントも一律で無制限に
      dir.up { execute "UPDATE tenants SET monthly_invoice_limit = NULL" }
    end
  end
end

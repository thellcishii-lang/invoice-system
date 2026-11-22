# 開発用シード: デモテナントと管理者ユーザー（冪等）
tenant = Tenant.find_or_create_by!(name: "Everyone's合同会社") do |t|
  t.postal_code = "357-0123"
  t.address = "埼玉県飯能市中藤下郷23-21"
  t.phone = "050-6881-6160"
  t.email = "admin@example.co.jp"
end

# 自社テナントは運営者自身のため、課金は契約中・請求書の上限なし
tenant.update!(billing_status: :active, monthly_invoice_limit: nil)

tenant.users.find_or_create_by!(email_address: "admin@example.co.jp") do |user|
  user.name = "管理者"
  user.password = "password"
  user.password_confirmation = "password"
end

# デモ取引先（2件）
tenant.clients.find_or_create_by!(name: "株式会社サンプル商事") do |client|
  client.name_kana = "カブシキガイシャサンプルショウジ"
  client.postal_code = "100-0001"
  client.address = "東京都千代田区千代田1-1"
  client.phone = "03-1111-1111"
  client.email = "info@sample.example.co.jp"
  client.contact_person = "山田太郎"
  client.payment_terms = "月末締め・翌月末払い"
  client.registration_number = "T1111111111111"
end

tenant.clients.find_or_create_by!(name: "有限会社テスト工務店") do |client|
  client.name_kana = "ユウゲンガイシャテストコウムテン"
  client.postal_code = "530-0001"
  client.address = "大阪府大阪市北区梅田1-1"
  client.phone = "06-2222-2222"
  client.email = "info@test-koumuten.example.co.jp"
  client.contact_person = "佐藤花子"
  client.payment_terms = "納品後30日以内"
end

# デモ品目（3件、品目コードは自動採番）
tenant.items.find_or_create_by!(name: "システム利用料") do |item|
  item.unit_price = 39_800
  item.unit = "月"
  item.tax_rate = "standard"
  item.description = "月額のシステム利用料"
end

tenant.items.find_or_create_by!(name: "導入支援作業") do |item|
  item.unit_price = 10_000
  item.unit = "時間"
  item.tax_rate = "standard"
  item.description = "導入支援の作業費（1時間あたり）"
end

tenant.items.find_or_create_by!(name: "新聞・書籍代") do |item|
  item.unit_price = 2_000
  item.unit = "冊"
  item.tax_rate = "reduced"
  item.description = "軽減税率対象の新聞・書籍"
end

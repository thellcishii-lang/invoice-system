# 開発用シード: デモテナントと管理者ユーザー（冪等）
tenant = Tenant.find_or_create_by!(name: "Everyone's合同会社") do |t|
  t.postal_code = "357-0123"
  t.address = "埼玉県飯能市中藤下郷23-21"
  t.phone = "050-6881-6160"
  t.email = "admin@example.co.jp"
end

tenant.users.find_or_create_by!(email_address: "admin@example.co.jp") do |user|
  user.name = "管理者"
  user.password = "password"
  user.password_confirmation = "password"
end

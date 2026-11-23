class AddMemberAndFilterFields < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :password_set_at, :datetime
    # 既存ユーザーはパスワード設定済みとして扱う
    execute "UPDATE users SET password_set_at = created_at WHERE password_set_at IS NULL"

    add_reference :documents, :created_by, foreign_key: { to_table: :users }
    add_column :documents, :internal_memo, :text
    add_column :documents, :public_viewed_at, :datetime
  end

  def down
    remove_column :documents, :public_viewed_at
    remove_column :documents, :internal_memo
    remove_reference :documents, :created_by, foreign_key: { to_table: :users }
    remove_column :users, :password_set_at
  end
end

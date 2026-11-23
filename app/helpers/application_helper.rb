module ApplicationHelper
  # 左カラム（サイドバー）のメニュー項目。現在表示中の項目は freee 風に
  # 薄い青地＋青文字＋左の青バーで示す。
  def sidebar_link_to(label, path, active: false)
    classes = if active
      "block px-4 py-2 text-sm font-bold text-blue-700 bg-blue-50 border-l-4 border-blue-600"
    else
      "block px-4 py-2 text-sm text-gray-700 border-l-4 border-transparent hover:bg-gray-100 hover:text-gray-900"
    end
    link_to label, path, class: classes
  end

  # サイドバーのグループ見出し
  def sidebar_heading(label)
    tag.p label, class: "px-4 pt-4 pb-1 text-xs font-bold text-gray-400"
  end

  # サイドバーの展開メニュー内の子項目（一覧・テンプレートなど）
  def sidebar_sub_link_to(label, path, active: false)
    classes = if active
      "block pl-9 pr-4 py-1.5 text-sm font-bold text-blue-700 bg-blue-50 border-l-4 border-blue-600"
    else
      "block pl-9 pr-4 py-1.5 text-sm text-gray-600 border-l-4 border-transparent hover:bg-gray-100 hover:text-gray-900"
    end
    link_to label, path, class: classes
  end
end

class ItemCategory < ApplicationRecord
  # 品目の分類ツリー。横（兄弟）にも縦（子分類＝階層）にもいくつでも広げられる。
  belongs_to :tenant
  belongs_to :parent, class_name: "ItemCategory", optional: true
  has_many :children, class_name: "ItemCategory", foreign_key: :parent_id,
           dependent: :restrict_with_error, inverse_of: :parent
  has_many :items, dependent: :nullify

  scope :ordered, -> { order(:position, :id) }
  scope :roots, -> { where(parent_id: nil) }

  # セグメント（親の中での3桁番号）は自動採番・変更不可・再利用なし。
  # 親を変えたときだけ、新しい親の下で採番し直す。
  before_save :reassign_segment_on_parent_change, if: -> { persisted? && parent_id_changed? }
  before_save :assign_segment, if: -> { segment.blank? }

  # 分類自体のコード: 先頭の階層だけ "A001"、以降は "-001001…" と続く
  # 例: A001 / A001-001 / A001-001001
  def full_code
    parts = (ancestors.map(&:segment) + [ segment ]).compact
    return "" if parts.empty?

    code = "A#{parts.first}"
    code += "-#{parts[1..].join}" if parts.size > 1
    code
  end

  validates :name, presence: true
  validate :parent_must_be_in_same_tenant
  validate :parent_must_not_create_a_cycle

  # セレクトボックス用: ツリー順にインデントした [ラベル, id] の配列
  def self.tree_options(tenant)
    options = []
    walk = lambda do |category, depth|
      options << [ "#{"　" * depth}#{category.name}", category.id ]
      category.children.ordered.each { |child| walk.call(child, depth + 1) }
    end
    tenant.item_categories.roots.ordered.each { |root| walk.call(root, 0) }
    options
  end

  def descendants
    children.flat_map { |child| [ child ] + child.descendants }
  end

  # 自分と配下すべての id（絞り込み用）
  def subtree_ids
    [ id ] + descendants.map(&:id)
  end

  def ancestors
    list = []
    node = parent
    while node
      list.unshift(node)
      node = node.parent
    end
    list
  end

  def path_name
    (ancestors.map(&:name) + [ name ]).join(" ＞ ")
  end

  private
    def assign_segment
      if parent
        parent.with_lock do
          parent.increment!(:child_segment_counter)
          self.segment = format("%03d", parent.child_segment_counter)
        end
      else
        tenant.with_lock do
          tenant.increment!(:item_category_counter)
          self.segment = format("%03d", tenant.item_category_counter)
        end
      end
    end

    def reassign_segment_on_parent_change
      self.segment = nil
    end

    def parent_must_be_in_same_tenant
      return if parent.blank?

      errors.add(:parent, "は同じ事業者の分類にしてください") if parent.tenant_id != tenant_id
    end

    def parent_must_not_create_a_cycle
      return if parent.blank? || id.blank?

      node = parent
      while node
        if node.id == id
          errors.add(:parent, "に自分や自分の配下の分類は選べません")
          break
        end
        node = node.parent
      end
    end
end

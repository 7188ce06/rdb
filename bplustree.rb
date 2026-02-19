require 'test/unit/assertions'
include Test::Unit::Assertions

MAX_LEAF_KEYS = 4
LEAF_PROMO_INDEX = 2

class Tree
  attr_accessor :root
  def initialize(root)
    @root = root
  end

  def ==(other)
    @root == other.root
  end
end

class Leaf
  attr_accessor :keys, :parent

  def initialize(*keys)
    # XXX: The min number of keys is actually 2 for a leaf.
    raise "error" if keys.size() == 0
    @keys = keys
  end

  def ==(other)
    @keys == other.keys
  end
end

class Internal
  attr_accessor :keys, :childs

  def initialize(keys, childs)
    raise "error" if keys.size() + 1 != childs.size()
    @keys = keys
    @childs = childs
  end

  def ==(other)
    @keys == other.keys and @childs == other.childs
  end
end

def insert!(tree, value)
  return insert_helper!(tree, tree.root, value)
end

def insert_helper!(tree, node, value)
  if node.is_a?(Leaf)
    i = 0
    while i < node.keys.size()
      if value < node.keys[i]
        break
      end
      i += 1
    end
    node.keys.insert(i, value)
    assert(node.keys.size() <= MAX_LEAF_KEYS+1)

    if node.keys.size() == MAX_LEAF_KEYS + 1
      promote!(tree, node)
    end
  else
    assert(node.is_a?(Internal))
    i = 0
    while i < node.keys.size()
      if value < node.keys[i]
        break
      end
      i += 1
    end
    insert_helper!(tree, node.childs[i], value)
  end
end

def promote!(tree, node)
  pkey = node.keys[LEAF_PROMO_INDEX]
  if node.is_a?(Leaf)
    left = Leaf.new(*node.keys[0...LEAF_PROMO_INDEX])
    right = Leaf.new(*node.keys[LEAF_PROMO_INDEX..])
    if node.object_id == tree.root.object_id
      tree.root = Internal.new([pkey], [left, right])
      left.parent = tree.root
      right.parent = tree.root
    else
      # Which child# is this node currently for its parent?
      orig_i = 0
      while node.object_id != node.parent.childs[orig_i].object_id
        orig_i += 1
      end
      puts "OI: #{orig_i}"

      # The orig_i child is goes with the orig_i separator.
      # And the promo key should immediately follow the orig_i separator.
      node.parent.keys.insert(orig_i, pkey)
      assert(node.parent.keys.size() <= MAX_LEAF_KEYS+1)
      node.parent.childs[orig_i] = left
      node.parent.childs.insert(orig_i+1, right)
      left.parent = node.parent
      right.parent = node.parent

      if node.parent.keys.size() == MAX_LEAF_KEYS
        promote!(tree, node.parent)
      end
    end
  else
    raise "implement"
  end
end

def delete(root, value)

end

def find(root, value)

end

def findRange(root, low, high)

end

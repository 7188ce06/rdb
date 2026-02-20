require 'test/unit/assertions'
include Test::Unit::Assertions

MIN_LEAF_KEYS = 2
MAX_LEAF_KEYS = 4
MIN_INTERNAL_CHILDREN = 2
MAX_INTERNAL_CHILDREN = 4
LEAF_PROMO_INDEX = 2
INTERNAL_PROMO_INDEX = 1

class Tree
  attr_accessor :root
  def initialize(root)
    @root = root
  end

  def ==(other)
    other.is_a?(Tree) and @root == other.root
  end
end

class Leaf
  attr_accessor :keys, :parent, :next_leaf

  def initialize(*keys)
    # XXX: The min number of keys is actually 2 for a leaf.
    raise "error" if keys.size() == 0
    @keys = keys
  end

  def ==(other)
    other.is_a?(Leaf) and @keys == other.keys and @parent == other.parent and @next_leaf == other.next_leaf
  end
end

class Internal
  attr_accessor :keys, :childs, :parent

  def initialize(keys, childs)
    raise "error: mismatch sizes for keys-childs" if keys.size() + 1 != childs.size()
    @keys = keys
    @childs = childs
  end

  def ==(other)
    other.is_a?(Internal) and @keys == other.keys and @childs == other.childs and @parent == other.parent
  end
end

def insert!(tree, *values)
  values.each {|v| insert_helper!(tree, tree.root, v)}
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
  if node.is_a?(Leaf)
    pkey = node.keys[LEAF_PROMO_INDEX]
    if node.object_id == tree.root.object_id
      right_keys = node.keys.slice!(LEAF_PROMO_INDEX..)
      right = Leaf.new(*right_keys)
      left = node

      tree.root = Internal.new([pkey], [left, right])
      left.parent = tree.root
      left.next_leaf = right
      right.parent = tree.root
    else
      right_keys = node.keys.slice!(LEAF_PROMO_INDEX..)
      right = Leaf.new(*right_keys)
      right.parent = node.parent
      right.next_leaf = node.next_leaf
      node.next_leaf = right

      # Which child# is @node for its parent?
      node_child_i = 0
      while node.object_id != node.parent.childs[node_child_i].object_id
        node_child_i += 1
      end

      # XXX: Improve this explanation.
      # The node_child_i child goes with the node_child_i separator.
      # And the promo key should immediately follow the node_child_i separator.
      node.parent.keys.insert(node_child_i, pkey)
      assert(node.parent.keys.size() <= MAX_LEAF_KEYS+1)
      node.parent.childs.insert(node_child_i+1, right)

      if node.parent.keys.size() == MAX_LEAF_KEYS
        promote!(tree, node.parent)
      end
    end
  else
    assert(node.is_a?(Internal))

    pkey = node.keys[INTERNAL_PROMO_INDEX]
    right_keys = node.keys.slice!((INTERNAL_PROMO_INDEX+1)..)
    right_childs = node.childs.slice!((INTERNAL_PROMO_INDEX+1)..)
    if node.object_id == tree.root.object_id
      right = Internal.new(right_keys, right_childs)
      right.childs.each {|c| c.parent = right}
      node.keys.delete_at(INTERNAL_PROMO_INDEX)
      left = node

      tree.root = Internal.new([pkey], [left, right])
      left.parent = tree.root
      right.parent = tree.root
    else
      i = 0
      while i < node.parent.keys.size()
        if pkey < node.parent.keys[i]
          break
        end
        i += 1
      end
      node.parent.keys.insert(i, pkey)
      assert(node.parent.keys.size() <= MAX_LEAF_KEYS+1)

      right = Internal.new(right_keys, right_childs)
      right.childs.each {|c| c.parent = right}
      right.parent = node.parent
      node.parent.childs.insert(i+1, right)

      # Fix the left.
      node.keys.delete_at(INTERNAL_PROMO_INDEX)

      if node.parent.keys.size() == MAX_LEAF_KEYS
        promote!(tree, node.parent)
      end
    end
  end
end

def delete!(tree, value)
  return delete_helper!(tree, tree.root, value)
end

def delete_helper!(tree, node, value)
  if node.is_a?(Leaf)
    i = 0
    while i < node.keys.size()
      if value == node.keys[i]
        break
      end
      i += 1
    end

    if i == node.keys.size()
      return
    end

    node.keys.delete_at(i)
    if node.object_id == tree.root.object_id
      return
    end

    if i == 0
      search_at = node.parent
      while search_at != nil
        j = 0
        while j < search_at.keys.size()
          if value == search_at.keys[j]
            break
          end
          j += 1
        end
        if j < search_at.keys.size()
          search_at.keys[j] = node.keys[0]
          break
        end
        search_at = search_at.parent
      end
      # HACK: Assumes that if we don't find an internal matching node then we
      #       had been looking for a key that has the same value as the
      #       leftmost key of the leftmost leaf.  This should be asserted on.
    end

    if node.keys.size() < MIN_LEAF_KEYS
      # underflow
      #
      # first try to get a donation from the right or left.
      i = 0
      while i < node.parent.childs.size()
        if node.parent.childs[i] == node
          break
        end
        i += 1
      end
      assert(i < node.parent.childs.size())

      # Can we take a donation from the right?
      if i < node.parent.childs.size() - 1
        rightsib = node.parent.childs[i+1]
        assert(rightsib.is_a?(Leaf))
        if rightsib.keys.size() > MIN_LEAF_KEYS
          key = rightsib.keys.slice!(0)
          node.keys.append(key)

          # Fix the internal node.
          # XXX: Instead, we could do an upwards search for it.
          (inode, keyidx) = findInt(tree, key)
          assert(inode.is_a?(Internal))
          inode.keys[keyidx] = rightsib.keys[0]
          return
        end
      end

      # Can we take a donation from the left?
      if i > 0
        leftsib = node.parent.childs[i-1]
        assert(leftsib.is_a?(Leaf))
        if leftsib.keys.size() > MIN_LEAF_KEYS
          key = leftsib.keys.slice!(-1)
          node.keys.insert(0, key)

          # Fix the internal node.
          # XXX: Instead, we could do an upwards search for it.
          (inode, keyidx) = findInt(tree, node.keys[1])
          assert(inode.is_a?(Internal))
          inode.keys[keyidx] = key
          return
        end
      end

      # Can we merge with the right?
      if i < node.parent.childs.size() - 1
        rightsib = node.parent.childs[i+1]
        assert(rightsib.is_a?(Leaf))
        if rightsib.keys.size() + node.keys.size() <= MAX_LEAF_KEYS
          node.keys += rightsib.keys
          node.next_leaf = rightsib.next_leaf
          node.parent.childs.delete_at(i+1)
          node.parent.keys.delete_at(i)

          # Did we underflow the parent?
          if node.parent.childs.size() < MIN_INTERNAL_CHILDREN
            raise "implement"
          end

          return
        end
      end

      # Can we merge with the left?
      if i > 0
        leftsib = node.parent.childs[i-1]
        assert(leftsib.is_a?(Leaf))
        if leftsib.keys.size() + node.keys.size() <= MAX_LEAF_KEYS
          leftsib.keys += node.keys
          leftsib.next_leaf = node.next_leaf
          node.parent.childs.delete_at(i)
          node.parent.keys.delete_at(i-1)

          # Did we underflow the parent?
          if node.parent.childs.size() < MIN_INTERNAL_CHILDREN
            raise "implement"
          end

          return
        end
      end
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
    delete_helper!(tree, node.childs[i], value)
  end
end

def findInt(tree, key)
  findIntHelper(tree.root, key)
end

def findIntHelper(node, key)
  if node.is_a?(Leaf)
    return nil
  end

  assert(node.is_a?(Internal))
  i = 0
  while i < node.keys.size()
    if key == node.keys[i]
      return [node, i]
    elsif key < node.keys[i]
      return findIntHelper(node.childs[i], key)
    end
    i += 1
  end
end

def find(root, value)

end

def findRange(root, low, high)

end

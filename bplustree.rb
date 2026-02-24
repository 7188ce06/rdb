require 'test/unit/assertions'
include Test::Unit::Assertions

MIN_LEAF_KEYS = 2
MAX_LEAF_KEYS = 4
MIN_INTERNAL_CHILDREN = 2
MAX_INTERNAL_CHILDREN = 4
LEAF_PROMO_INDEX = 2
INTERNAL_PROMO_INDEX = 1

# The empty tree (ie, the tree with no keys) is the tree with a root node that
# is an empty leaf.
class Tree
  attr_accessor :root
  def initialize(root=nil)
    if root.nil?
      @root = Leaf.new()
    else
      @root = root
    end
  end

  def ==(other)
    other.is_a?(Tree) and @root == other.root
  end
end

class Leaf
  attr_accessor :keys, :parent, :next_leaf

  def initialize(*keys)
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

class DuplicateKeyError < StandardError
end

# There are three subcases when the root node is a leaf.
# (1) root node is empty.
# (2) root node is non-empty, but not packed.
# (3) root node is packed.
#
# There are N subcases when the root node is not a leaf.
# (1) The relevant leaf is non-empty, but not packed.
# (2) The relevant leaf is packed. (Is the parent also packed? grandparent?)
def insert!(tree, *values)
  values.each {|v| insert_helper!(tree, tree.root, v)}
end

def insert_helper!(tree, node, value)
  assert(is_sorted(node.keys))
  if node.is_a?(Leaf)
    i = 0
    while i < node.keys.size()
      if value == node.keys[i]
        raise DuplicateKeyError.new
      elsif value > node.keys[i]
        i += 1
      else
        assert(value < node.keys[i])
        break
      end
    end
    node.keys.insert(i, value)
    assert(node.keys.size() <= MAX_LEAF_KEYS+1)

    if node.keys.size() == MAX_LEAF_KEYS + 1
      promote_from_leaf!(tree, node)
    end
  else
    assert(node.is_a?(Internal))
    i = 0
    while i < node.keys.size()
      if value == node.keys[i]
        raise DuplicateKeyError.new
      elsif value > node.keys[i]
        i += 1
      else
        assert(value < node.keys[i])
        break
      end
    end
    insert_helper!(tree, node.childs[i], value)
  end
end

def promote_from_leaf!(tree, node)
  assert(node.is_a?(Leaf))
  assert(is_sorted(node.keys))
  pkey = node.keys[LEAF_PROMO_INDEX]
  if node.object_id == tree.root.object_id
    right_keys = node.keys.slice!(LEAF_PROMO_INDEX..)
    right = Leaf.new(*right_keys)
    left = node
    left.next_leaf = right

    tree.root = Internal.new([pkey], [left, right])
    left.parent = tree.root
    right.parent = tree.root
  else
    assert(!node.parent.nil?)

    # What index is @node at for its parent?
    node_child_i = 0
    while node.object_id != node.parent.childs[node_child_i].object_id
      node_child_i += 1
    end

    right_keys = node.keys.slice!(LEAF_PROMO_INDEX..)
    right = Leaf.new(*right_keys)
    left = node
    right.next_leaf = left.next_leaf
    left.next_leaf = right
    right.parent = node.parent

    # @left will occupy the same position that @node occupied in the parent's
    # child array.  @right will occupy the subsequent position.  The first
    # element of @right must also become a key for the parent that comes after
    # the key which is the first element of @left.
    node.parent.childs.insert(node_child_i+1, right)
    node.parent.keys.insert(node_child_i, pkey)
    assert(node.parent.keys.size() + 1 == node.parent.childs.size())
    assert(node.parent.childs.size() <= MAX_INTERNAL_CHILDREN+1)

    if node.parent.childs.size() > MAX_INTERNAL_CHILDREN
      promote_from_internal!(tree, node.parent)
    end
  end
end

# XXX: Is this buggy?
def promote_from_internal!(tree, node)
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
    assert(node.parent.keys.size() <= MAX_INTERNAL_CHILDREN)

    right = Internal.new(right_keys, right_childs)
    right.childs.each {|c| c.parent = right}
    right.parent = node.parent
    node.parent.childs.insert(i+1, right)
    assert(node.parent.childs.size() <= MAX_INTERNAL_CHILDREN+1)

    # Fix the left.
    node.keys.delete_at(INTERNAL_PROMO_INDEX)

    if node.parent.childs.size() == MAX_INTERNAL_CHILDREN+1
      promote_from_internal!(tree, node.parent)
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

    # Return if the leaf doesn't have the key.
    if i == node.keys.size()
      return
    end

    node.keys.delete_at(i)
    if node.object_id == tree.root.object_id
      return
    end

    # XXX: Is this right?
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
      handle_leaf_underflow!(tree, node)
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

def handle_leaf_underflow!(tree, node)
  assert(node.is_a?(Leaf))
  assert(tree.root.object_id != node.object_id)

  # first try to get a donation from the right or left.
  # then try to merge.
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

      # Fix the parent.
      node.parent.keys[i] = rightsib.keys[0]
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

      # Fix the parent.
      node.parent.keys[i-1] = key
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
        handle_internal_underflow!(tree, node.parent)
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
        handle_internal_underflow!(tree, node.parent)
      end

      return
    end
  end

  raise "unreachable"
end

# Notice: An underflowing root can't merge or accept donations because it
# doesn't have any siblings.
def handle_internal_underflow!(tree, node)
  assert(node.is_a?(Internal))
  assert(node.childs.size() < MIN_INTERNAL_CHILDREN)
  assert(node.keys.size() + 1 == node.childs.size())

  if tree.root.object_id == node.object_id
    assert_equal(node.childs.size(), 1)
    tree.root = node.childs[0]
    tree.root.parent = nil
    assert(tree.root.is_a?(Leaf))
    return
  else
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
      assert(rightsib.is_a?(Internal))
      if rightsib.childs.size() > MIN_INTERNAL_CHILDREN
        # The least element of the @node subtree does not change because it
        # already contains elements that are smaller than any element in a
        # right sibling.
        # The least element of the right sibling changes because it loses its
        # smallest subtree. Therefore, the parent key between @node and its
        # next right sibling must be updated.

        # Accept the donation.
        child = rightsib.childs.slice!(0)
        key = least_key_in_subtree(child)
        node.childs.append(child)
        node.keys.append(key)
        child.parent = node

        # Fix the sibling.
        rightsib.keys.delete_at(0)

        # Fix the parent.
        node.parent.keys[i] = least_key_in_subtree(rightsib.childs[0])
        return
      end
    end

    # Can we take a donation from the left?
    if i > 0
      leftsib = node.parent.childs[i-1]
      assert(leftsib.is_a?(Internal))
      if leftsib.childs.size() > MIN_LEAF_KEYS
        # The least element of the @node subtree changes because its accepting
        # elements from a left subtree. Therefore, the parent key between left
        # sibling and @node must be updated.
        # The least element of the left sibling's tree does not change.

        # Accept the donation.
        child = leftsib.childs.slice!(-1)
        key = least_key_in_subtree(node.childs[0])
        node.childs.insert(0, child)
        node.keys.insert(0, key)
        child.parent = node

        # Fix up the sibling.
        leftsib.keys.delete_at(-1)

        # Fix the internal node.
        node.parent.keys[i-1] = least_key_in_subtree(child)
        return
      end
    end

    # Can we merge with the right?
    # XXX: This is buggy.
    if i < node.parent.childs.size() - 1
      rightsib = node.parent.childs[i+1]
      assert(rightsib.is_a?(Internal))
      if node.childs.size() + rightsib.childs.size() <= MAX_INTERNAL_CHILDREN
        # HACK: If the min-max configuration was different, then we could be
        # merging when node has more than one child in which case this code would
        # not work.
        assert(node.childs.size() == 1)
        rightsib.childs.insert(0, node.childs[0])
        rightsib.childs[0].parent = rightsib
        rightsib.keys.insert(0, least_key_in_subtree(rightsib.childs[1]))
        node.parent.childs.delete_at(i)
        node.parent.keys.delete_at(i)

        if node.parent.childs.size < MIN_INTERNAL_CHILDREN
          handle_internal_underflow!(tree, node.parent)
        end

        return
      end
    end

    # Can we merge with the left?
    # XXX: This is buggy.
    if i > 0
      leftsib = node.parent.childs[i-1]
      assert(leftsib.is_a?(Internal))
      if node.childs.size() + leftsib.childs.size() <= MAX_INTERNAL_CHILDREN
        # HACK: If the min-max configuration was different, then we could be
        # merging when node has more than one child in which case this code would
        # not work.
        assert(node.childs.size() == 1)
        leftsib.childs.insert(-1, node.childs[0])
        leftsib.childs[-1].parent = leftsib
        leftsib.keys.insert(-1, least_key_in_subtree(leftsib.childs[-1]))
        node.parent.childs.delete_at(i)
        node.parent.keys.delete_at(i-1)

        if node.parent.childs.size < MIN_INTERNAL_CHILDREN
          handle_internal_underflow!(tree, node.parent)
        end
      end
    end
  end
end

def least_key_in_subtree(node)
  if node.is_a?(Leaf)
    # XXX: What if the tree is empty?
    return node.keys[0]
  else
    assert(node.is_a?(Internal))
    return least_key_in_subtree(node.childs[0])
  end
end

# XXX: Implement
def find(root, value)
  raise "implement"
end

# XXX: Implement
def findRange(root, low, high)
  raise "implement"
end

def is_sorted(xs)
  xs == xs.sort
end

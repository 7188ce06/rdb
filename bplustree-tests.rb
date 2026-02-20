require 'test/unit'
require 'tempfile'
require_relative 'bplustree'

class Tests < Test::Unit::TestCase
  def test_insert
    # 10
    tree = Tree.new(Leaf.new(10))
    tree2 = Tree.new(Leaf.new(10))

    # 10, 20
    insert!(tree, 20)
    tree2.root.keys.append(20)
    assert_equal(tree, tree2)

    # 5, 10, 20
    insert!(tree, 5)
    tree2.root.keys.insert(0, 5)
    assert_equal(tree, tree2)

    # 5, 10, 20, 100
    insert!(tree, 100)
    tree2.root.keys.append(100)
    assert_equal(tree, tree2)

    #      10
    # [1,5] [10,20,100]
    insert!(tree, 1)
    tree2 = Tree.new(Internal.new([10], [Leaf.new(1, 5), Leaf.new(10, 20, 100)]))
    tree2.root.childs[0].parent = tree2.root.childs[1].parent = tree2.root
    tree2.root.childs[0].next_leaf = tree2.root.childs[1]
    assert_equal(tree, tree2)

    #       10
    # [1,2,5] [10,20,100]
    insert!(tree, 2)
    tree2.root.childs[0].keys.insert(1, 2)
    assert_equal(tree, tree2)

    #         10
    # [1,2,5,6] [10,20,100]
    insert!(tree, 6)
    tree2.root.childs[0].keys.insert(3, 6)
    assert_equal(tree, tree2)

    #       [4,10]
    # [1,2] [4,5,6] [10,20,100]
    insert!(tree, 4)
    tree2 = Tree.new(Internal.new(
      [4,10], [Leaf.new(1,2), Leaf.new(4,5,6), Leaf.new(10,20,100)]))
    tree2.root.childs[0].parent = tree2.root.childs[1].parent = tree2.root.childs[2].parent = tree2.root
    tree2.root.childs[0].next_leaf = tree2.root.childs[1]
    tree2.root.childs[1].next_leaf = tree2.root.childs[2]
    assert_equal(tree, tree2)

    #       [4,6,10]
    # [1,2] [4,5] [6,7,8] [10,20,100]
    insert!(tree, 7)
    insert!(tree, 8)
    tree2 = Tree.new(Internal.new(
      [4,6,10],
      [Leaf.new(1,2), Leaf.new(4,5), Leaf.new(6,7,8), Leaf.new(10,20,100)]))
    fix_parents!(tree2)
    tree2.root.childs[0].next_leaf = tree2.root.childs[1]
    tree2.root.childs[1].next_leaf = tree2.root.childs[2]
    tree2.root.childs[2].next_leaf = tree2.root.childs[3]
    assert_equal(tree, tree2)

    # TEST: Internal root overflow
    #             [6]
    #     [4]              [10,25]
    # [1,2] [4,5]    [6,7,8] [10,20] [25,26,100]
    insert!(tree, 25)
    insert!(tree, 26)
    tree2 = Tree.new(
      Internal.new([6],
        [Internal.new([4], [Leaf.new(1,2), Leaf.new(4, 5)]),
         Internal.new([10,25], [Leaf.new(6,7,8), Leaf.new(10,20), Leaf.new(25,26,100)])]))
    fix_parents!(tree2)
    tree2.root.childs[0].childs[0].parent = tree2.root.childs[0].childs[1].parent = tree2.root.childs[0]
    tree2.root.childs[0].childs[0].next_leaf = tree2.root.childs[0].childs[1]
    tree2.root.childs[0].childs[1].next_leaf = tree2.root.childs[1].childs[0]

    tree2.root.childs[1].childs[0].next_leaf = tree2.root.childs[1].childs[1]
    tree2.root.childs[1].childs[1].next_leaf = tree2.root.childs[1].childs[2]

    assert_equal(tree, tree2)

    # TEST: leaf node overflow
    #             [6]
    #     [4]              [10,25,27]
    # [1,2] [4,5]    [6,7,8] [10,20] [25,26] [27,28,100]
    insert!(tree, 27)
    insert!(tree, 28)
    tree2 = Tree.new(
      Internal.new([6],
        [Internal.new([4], [Leaf.new(1,2), Leaf.new(4, 5)]),
         Internal.new([10,25,27], [Leaf.new(6,7,8), Leaf.new(10,20), Leaf.new(25,26), Leaf.new(27,28,100)])]))
    fix_parents!(tree2)
    tree2.root.childs[0].childs[0].next_leaf = tree2.root.childs[0].childs[1]
    tree2.root.childs[0].childs[1].next_leaf = tree2.root.childs[1].childs[0]

    tree2.root.childs[1].childs[0].next_leaf = tree2.root.childs[1].childs[1]
    tree2.root.childs[1].childs[1].next_leaf = tree2.root.childs[1].childs[2]
    tree2.root.childs[1].childs[2].next_leaf = tree2.root.childs[1].childs[3]

    assert_equal(tree, tree2)

    # TEST: Internal non-root overflow
    #                       [6,12]
    #     [4]              [10]                  [25,27]
    # [1,2] [4,5]    [6,7,8] [10,11]      [12,13,20] [25,26] [27,28,100]
    insert!(tree, 11)
    insert!(tree, 12)
    insert!(tree, 13)
    tree2 = Tree.new(
      Internal.new([6,12],
        [Internal.new([4], [Leaf.new(1,2), Leaf.new(4, 5)]),
         Internal.new([10], [Leaf.new(6,7,8), Leaf.new(10,11)]),
         Internal.new([25,27], [Leaf.new(12,13,20), Leaf.new(25,26), Leaf.new(27,28,100)])]))
    fix_parents!(tree2)
    tree2.root.childs[0].childs[0].next_leaf = tree2.root.childs[0].childs[1]
    tree2.root.childs[0].childs[1].next_leaf = tree2.root.childs[1].childs[0]

    tree2.root.childs[1].childs[0].next_leaf = tree2.root.childs[1].childs[1]
    tree2.root.childs[1].childs[1].next_leaf = tree2.root.childs[2].childs[0]

    tree2.root.childs[2].childs[0].next_leaf = tree2.root.childs[2].childs[1]
    tree2.root.childs[2].childs[1].next_leaf = tree2.root.childs[2].childs[2]

    assert_equal(tree, tree2)
  end

  def test_delete
    # XXX: What should happen if we delete the only key of a tree?

    # Delete first key from root-leaf.
    tree = Tree.new(Leaf.new(10,20))
    delete!(tree, 10)
    tree2 = Tree.new(Leaf.new(20))
    assert_equal(tree, tree2)

    # Delete last key from root-leaf.
    tree = Tree.new(Leaf.new(10, 20))
    delete!(tree, 20)
    tree2 = Tree.new(Leaf.new(10))
    assert_equal(tree, tree2)

    # Delete non-first key from non-first non-root leaf.
    tree = Tree.new(Leaf.new(1, 2, 15, 20))
    insert!(tree, 10)
    tree2 = Tree.new(Leaf.new(1, 2, 15, 20))
    insert!(tree2, 10)
    tree2.root.childs[1].keys.delete_at(1)
    delete!(tree, 15)
    assert_equal(tree, tree2)

    # Delete the first key from non-first non-root leaf.
    tree = Tree.new(Leaf.new(1, 2, 15, 20))
    insert!(tree, 10)
    tree2 = Tree.new(Leaf.new(1, 2, 15, 20))
    insert!(tree2, 10)
    tree2.root.childs[1].keys.delete_at(0)
    tree2.root.keys = [15]
    delete!(tree, 10)
    assert_equal(tree, tree2)

    # Delete the first key from non-root first leaf.
    tree = Tree.new(Leaf.new(1, 2, 15, 20))
    insert!(tree, 10)
    insert!(tree, 3)
    tree2 = Tree.new(Leaf.new(1, 2, 15, 20))
    insert!(tree2, 10)
    insert!(tree2, 3)
    tree2.root.childs[0].keys.delete_at(0)
    delete!(tree, 1)
    assert_equal(tree, tree2)
  end
end

class TestsForHelpers < Test::Unit::TestCase
  def test_fix_parents
    tree = Tree.new(Leaf.new(10))
    tree2 = Tree.new(Leaf.new(10))
    fix_parents!(tree)
    assert_equal(tree, tree2)

    tree = Tree.new(Internal.new([10], [Leaf.new(1, 5), Leaf.new(10, 20, 100)]))
    tree.root.childs[0].next_leaf = tree.root.childs[1]
    fix_parents!(tree)
    tree2 = Tree.new(Leaf.new(10))
    insert!(tree2, 20)
    insert!(tree2, 5)
    insert!(tree2, 1)
    insert!(tree2, 100)
    assert_equal(tree, tree2)
  end
end

def get_first_leaf(tree)
  return get_first_leaf_helper(root)
end

def get_first_leaf_helper(node)
  if node.is_a?(Leaf)
    return node
  else
    return get_first_leaf_helper(node.childs[0])
  end
end

# Assumes that parent links are setup.
def get_next_leaf(leaf)
  if parent.nil?
    return nil
  end

  # go up the necessary amount
  node = leaf
  while !node.nil?
    i = 0
    while i < node.parent.keys.size()
      if node.parent.keys[i] == node.keys[0]
        break
      end
      i += 1
    end

    if i == leaf.parent.keys.size()
      i = 1
    else
      i += 1
    end

    if i < node.parent.childs.size()
      descend_from = node.parent.childs[i]
      break
    end

    node = node.parent
  end
  raise "bogus" if node.nil? or descend_from.nil?

  # descend
  while true
    if descend_from.is_a?(Leaf)
      return descend_from
    else
      descend_from = descend_from.childs[0]
    end
  end
end

def fix_parents!(tree)
  fix_parents_helper!(tree.root)
end

# Assume everything above and including this node is correct.
def fix_parents_helper!(node)
  if node.is_a?(Leaf)
    return
  end

  node.childs.each do |c|
    c.parent = node
    fix_parents_helper!(c)
  end
end

def fix_next_leaf_links!(tree)
  leaf = get_first_leaf(tree)

  while (nleaf = get_next_leaf(leaf)) != nil
    leaf.next_leaf = nleaf
  end
end

def fix_tree!(tree)
  fix_parents!(tree)
  fix_next_leaf_links!(tree)
end

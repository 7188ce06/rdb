require 'test/unit'
require 'tempfile'
require_relative 'bplustree'

class Tests < Test::Unit::TestCase
  def test_insert_empty_tree
    emptyA = Tree.new()
    emptyB = Tree.new()
    assert_equal(emptyA, emptyB)
    assert(emptyA.root.is_a?(Leaf))
    assert_equal(emptyA.root.keys, [])

    insert!(emptyA, 10)
    insert!(emptyB, 10)
    assert_equal(emptyA, emptyB)
    assert(emptyA.root.is_a?(Leaf))
    assert_equal(emptyA.root.keys, [10])

    assert_raises(DuplicateKeyError) {insert!(emptyA, 10)}
  end

  def test_insert
    # 10, 20
    tree = Tree.new(Leaf.new(10))
    insert!(tree, 20)
    tree2 = Tree.new(Leaf.new(10))
    tree2.root.keys.append(20)
    assert_equal(tree, tree2)
    assert_raises(DuplicateKeyError) {insert!(tree, 20)}

    # 5, 10, 20
    insert!(tree, 5)
    tree2.root.keys.insert(0, 5)
    assert_equal(tree, tree2)

    # 5, 10, 20, 100
    insert!(tree, 100)
    tree2.root.keys.append(100)
    assert_equal(tree, tree2)

    # TEST: Overflow when root is a leaf.
    #      10
    # [1,5] [10,20,100]
    insert!(tree, 1)
    tree2 = Tree.new(Internal.new([10], [Leaf.new(1, 5), Leaf.new(10, 20, 100)]))
    fix_tree!(tree2)
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
    fix_tree!(tree2)
    assert_equal(tree, tree2)

    #       [4,6,10]
    # [1,2] [4,5] [6,7,8] [10,20,100]
    insert!(tree, 7, 8)
    tree2 = Tree.new(Internal.new(
      [4,6,10],
      [Leaf.new(1,2), Leaf.new(4,5), Leaf.new(6,7,8), Leaf.new(10,20,100)]))
    fix_tree!(tree2)
    assert_equal(tree, tree2)

    # TEST: Internal root overflow
    #             [6]
    #     [4]              [10,25]
    # [1,2] [4,5]    [6,7,8] [10,20] [25,26,100]
    insert!(tree, 25, 26)
    tree2 = Tree.new(
      Internal.new([6],
        [Internal.new([4], [Leaf.new(1,2), Leaf.new(4, 5)]),
         Internal.new([10,25], [Leaf.new(6,7,8), Leaf.new(10,20), Leaf.new(25,26,100)])]))
    fix_tree!(tree2)
    assert_equal(tree, tree2)

    # TEST: leaf node overflow
    #             [6]
    #     [4]              [10,25,27]
    # [1,2] [4,5]    [6,7,8] [10,20] [25,26] [27,28,100]
    insert!(tree, 27, 28)
    tree2 = Tree.new(
      Internal.new([6],
        [Internal.new([4], [Leaf.new(1,2), Leaf.new(4, 5)]),
         Internal.new([10,25,27], [Leaf.new(6,7,8), Leaf.new(10,20), Leaf.new(25,26), Leaf.new(27,28,100)])]))
    fix_tree!(tree2)
    assert_equal(tree, tree2)

    # TEST: Internal non-root overflow
    #                       [6,12]
    #     [4]              [10]                  [25,27]
    # [1,2] [4,5]    [6,7,8] [10,11]      [12,13,20] [25,26] [27,28,100]
    insert!(tree, 11, 12, 13)
    tree2 = Tree.new(
      Internal.new([6,12],
        [Internal.new([4], [Leaf.new(1,2), Leaf.new(4, 5)]),
         Internal.new([10], [Leaf.new(6,7,8), Leaf.new(10,11)]),
         Internal.new([25,27], [Leaf.new(12,13,20), Leaf.new(25,26), Leaf.new(27,28,100)])]))
    fix_tree!(tree2)
    assert_equal(tree, tree2)
  end

  def test_insert_overflow_into_height_four_tree
    #                          [40,60,90]
    #     [25]            [50]               [75]                      [125,127,150]
    # [1,2] [25,26] [40,41]  [50,51]  [60,61]    [75,76]    [90,91] [125,126] [127,128, 129] [150,151,152,153]
    tree = Tree.new(
      Internal.new([40,60,90],
        [Internal.new([25], [Leaf.new(1,2), Leaf.new(25,26)]),
         Internal.new([50], [Leaf.new(40,41), Leaf.new(50,51)]),
         Internal.new([75], [Leaf.new(60,61), Leaf.new(75,76)]),
         Internal.new([125,150], [Leaf.new(90,91), Leaf.new(125,126,127,128), Leaf.new(150,151,152,153)])]))
    fix_tree!(tree)
    insert!(tree, 129)
    tree2 = Tree.new(
      Internal.new([40,60,90],
        [Internal.new([25], [Leaf.new(1,2), Leaf.new(25,26)]),
         Internal.new([50], [Leaf.new(40,41), Leaf.new(50,51)]),
         Internal.new([75], [Leaf.new(60,61), Leaf.new(75,76)]),
         Internal.new([125,127,150], [Leaf.new(90,91), Leaf.new(125,126), Leaf.new(127,128,129), Leaf.new(150,151,152,153)])]))
    fix_tree!(tree2)
    assert_equal(tree, tree2)

    #                             [60]
    #            [40]                                  [90,127]
    #     [25]            [50]               [75]                    [125]                              [150,152]
    # [1,2] [25,26] [40,41]  [50,51]  [60,61]    [75,76]        [90,91] [125,126]         [127,128, 129] [150,151] [152,153,154]
    insert!(tree, 154)
    tree2 = Tree.new(
      Internal.new([60],
        [Internal.new([40],
          [Internal.new([25], [Leaf.new(1,2), Leaf.new(25,26)]),
           Internal.new([50], [Leaf.new(40,41), Leaf.new(50,51)])]),
         Internal.new([90,127],
          [Internal.new([75], [Leaf.new(60,61), Leaf.new(75,76)]),
           Internal.new([125], [Leaf.new(90,91), Leaf.new(125,126)]),
           Internal.new([150,152], [Leaf.new(127,128,129), Leaf.new(150,151), Leaf.new(152,153,154)])])]))
    fix_tree!(tree2)
    assert_equal(tree, tree2)
  end

  def test_delete_for_height_one
    # Delete the tree's only key.
    tree = Tree.new(Leaf.new(10))
    delete!(tree, 10)
    tree2 = Tree.new()
    assert_equal(tree, tree2)
    assert(tree.root.is_a?(Leaf))
    assert_equal(tree.root.keys, [])

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
  end

  def test_delete_for_height_two
    # Delete the first key from the first leaf.
    tree = Tree.new(Leaf.new(1, 2, 15, 20))
    insert!(tree, 10, 3)
    delete!(tree, 1)
    tree2 = Tree.new(Internal.new([10], [Leaf.new(2,3), Leaf.new(10,15,20)]))
    fix_tree!(tree2)
    assert_equal(tree, tree2)

    # Delete non-first key from the first leaf.
    tree = Tree.new(Leaf.new(1, 2, 15, 20))
    insert!(tree, 10, 3)
    delete!(tree, 2)
    tree2 = Tree.new(Internal.new([10], [Leaf.new(1,3), Leaf.new(10,15,20)]))
    fix_tree!(tree2)
    assert_equal(tree, tree2)

    # Delete the first key from non-first leaf.
    tree = Tree.new(Leaf.new(1, 2, 15, 20))
    insert!(tree, 10)
    delete!(tree, 10)
    tree2 = Tree.new(Internal.new([15], [Leaf.new(1, 2), Leaf.new(15, 20)]))
    fix_tree!(tree2)
    assert_equal(tree, tree2)

    # Delete non-first key from non-first leaf.
    tree = Tree.new(Leaf.new(1, 2, 15, 20))
    insert!(tree, 10)
    delete!(tree, 15)
    tree2 = Tree.new(Internal.new([10], [Leaf.new(1, 2), Leaf.new(10, 20)]))
    fix_tree!(tree2)
    assert_equal(tree, tree2)

    # underflow first leaf causing donation from right
    tree = Tree.new(Leaf.new(1, 2, 15, 20))
    insert!(tree, 10)
    delete!(tree, 1)
    tree2 = Tree.new(Internal.new([15], [Leaf.new(2,10), Leaf.new(15,20)]))
    fix_tree!(tree2)
    assert_equal(tree, tree2)

    # underflow second leaf causing donation from left
    tree = Tree.new(Leaf.new(1, 2, 15, 20))
    insert!(tree, 10,3)
    delete!(tree, 10)
    delete!(tree, 15)
    tree2 = Tree.new(Internal.new([3], [Leaf.new(1,2), Leaf.new(3,20)]))
    fix_tree!(tree2)
    assert_equal(tree, tree2)

    # underflow first leaf causing right merge
    tree = Tree.new(Leaf.new(1, 2, 6, 10))
    insert!(tree, 5, 12, 14)
    delete!(tree, 2)
    tree2 = Tree.new(Internal.new([10], [Leaf.new(1,5,6), Leaf.new(10,12,14)]))
    fix_tree!(tree2)
    assert_equal(tree, tree2)

    # underflow last leaf causing left merge
    tree = Tree.new(Leaf.new(1, 2, 6, 10))
    insert!(tree, 5, 12, 14)
    delete!(tree, 12)
    delete!(tree, 14)
    tree2 = Tree.new(Internal.new([5], [Leaf.new(1,2), Leaf.new(5,6,10)]))
    fix_tree!(tree2)
    assert_equal(tree, tree2)

    # underflow first leaf causing right merge that underflows root
    tree = Tree.new(Leaf.new(1, 2, 6, 10))
    insert!(tree, 5)
    delete!(tree, 10)
    delete!(tree, 2)
    tree2 = Tree.new(Leaf.new(1, 5, 6))
    assert_equal(tree, tree2)

    # underflow non-first leaf causing left merge that underflows root
    tree = Tree.new(Leaf.new(1, 2, 6, 10))
    insert!(tree, 5)
    delete!(tree, 6)
    delete!(tree, 10)
    tree2 = Tree.new(Leaf.new(1, 2, 5))
    assert_equal(tree, tree2)
  end

  def test_delete_for_height_three
    # underflow first leaf causing right merge that underflows non-root parent.
    # it then accepts a donation from the right.
    tree = Tree.new(Internal.new([20],
      [Internal.new([10], [Leaf.new(1,2), Leaf.new(10,11)]),
       Internal.new([30, 40], [Leaf.new(20,21), Leaf.new(30,31), Leaf.new(40,41)])]))
    fix_tree!(tree)
    delete!(tree, 2)
    tree2 = Tree.new(Internal.new([30],
      [Internal.new([20], [Leaf.new(1,10,11), Leaf.new(20,21)]),
       Internal.new([40], [Leaf.new(30,31), Leaf.new(40,41)])]))
    fix_tree!(tree2)
    assert_equal(tree, tree2)

    # underflow last leaf causing left merge that underflows non-root parent.
    # it then accepts a donation from the left.
    tree = Tree.new(Internal.new([30],
      [Internal.new([10, 20], [Leaf.new(1,2), Leaf.new(10, 11), Leaf.new(20, 21)]),
       Internal.new([40], [Leaf.new(30,31), Leaf.new(40,41)])]))
    fix_tree!(tree)
    delete!(tree, 40)
    tree2 = Tree.new(Internal.new([20],
      [Internal.new([10], [Leaf.new(1,2), Leaf.new(10,11)]),
       Internal.new([30], [Leaf.new(20,21), Leaf.new(30,31,41)])]))
    fix_tree!(tree2)
    assert_equal(tree, tree2)

    # underflow first leaf causing right merge that underflows non-root parent.
    # it then merges to the right.
    tree = Tree.new(Internal.new([20,40],
      [Internal.new([10], [Leaf.new(1,2), Leaf.new(10,11)]),
       Internal.new([30], [Leaf.new(20,21), Leaf.new(30,31)]),
       Internal.new([50], [Leaf.new(40,41), Leaf.new(50,51)])]))
    fix_tree!(tree)
    delete!(tree, 2)
    tree2 = Tree.new(Internal.new([40],
      [Internal.new([20,30], [Leaf.new(1,10,11), Leaf.new(20,21), Leaf.new(30,31)]),
       Internal.new([50], [Leaf.new(40,41), Leaf.new(50,51)])]))
    fix_tree!(tree2)
    assert_equal(tree, tree2)

    # underflow last leaf causing left merge that underflows non-root parent.
    # it then merges to the left.
    tree = Tree.new(Internal.new([20,40],
      [Internal.new([10], [Leaf.new(1,2), Leaf.new(10,11)]),
       Internal.new([30], [Leaf.new(20,21), Leaf.new(30,31)]),
       Internal.new([50], [Leaf.new(40,41), Leaf.new(50,51)])]))
    fix_tree!(tree)
    delete!(tree, 51)
    tree2 = Tree.new(Internal.new([20],
      [Internal.new([10], [Leaf.new(1,2), Leaf.new(10,11)]),
       Internal.new([30,40], [Leaf.new(20,21), Leaf.new(30,31), Leaf.new(40,41,50)])]))
    fix_tree!(tree2)
    assert_equal(tree, tree2)
  end

  def test_all_underflow_for_height_three
    tree = Tree.new(
      Internal.new([100], [
        Internal.new([50], [Leaf.new(1,2),  Leaf.new(50,51)]),
        Internal.new([150], [Leaf.new(100,101), Leaf.new(150,151)])
      ])
    )
    fix_tree!(tree)
    delete!(tree, 151)

    expected = Tree.new(
      Internal.new([50,100], [
        Leaf.new(1,2), Leaf.new(50,51), Leaf.new(100,101,150)
      ])
    )
    fix_tree!(expected)
    assert_equal(expected, tree)
  end

  def test_delete_for_height_four
    # XXX: Implement.
  end

  def test_delete_internal_underflow_middle_node_right_merge_must_return
    # Root has 4 internal children; deleting 31 causes:
    # - leaf underflow in child1
    # - internal underflow in child1 (a middle child)
    # - merge-with-right should happen exactly once
    tree = Tree.new(
      Internal.new([20,40,60], [
        Internal.new([10], [Leaf.new(1,2),  Leaf.new(10,11)]),
        Internal.new([30], [Leaf.new(20,21), Leaf.new(30,31)]),
        Internal.new([50], [Leaf.new(40,41), Leaf.new(50,51)]),
        Internal.new([70], [Leaf.new(60,61), Leaf.new(70,71)])
      ])
    )
    fix_tree!(tree)
    delete!(tree, 31)

    expected = Tree.new(
      Internal.new([20,60], [
        Internal.new([10], [Leaf.new(1,2), Leaf.new(10,11)]),
        Internal.new([40,50], [Leaf.new(20,21,30), Leaf.new(40,41), Leaf.new(50,51)]),
        Internal.new([70], [Leaf.new(60,61), Leaf.new(70,71)])
      ])
    )
    fix_tree!(expected)
    assert_equal(expected, tree)
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
    insert!(tree2, 20, 5, 1, 100)
    assert_equal(tree, tree2)
  end

  def test_get_leaf
    tree = Tree.new(Leaf.new(10))
    assert_equal(get_first_leaf(tree), tree.root)
    assert_equal(get_next_leaf(get_first_leaf(tree)), nil)

    #      10
    # [1,5] [10,20,100]
    insert!(tree, 20, 5, 100, 1)
    assert_equal(get_first_leaf(tree), tree.root.childs[0])
    assert_equal(get_next_leaf(get_first_leaf(tree)), tree.root.childs[1])

    #       [4,6,10]
    # [1,2] [4,5] [6,7,8] [10,20,100]
    insert!(tree, 2, 6, 4, 7, 8)
    leaf0 = get_first_leaf(tree)
    assert_equal(leaf0, tree.root.childs[0])
    leaf1 = get_next_leaf(leaf0)
    assert_equal(leaf1, tree.root.childs[1])
    leaf2 = get_next_leaf(leaf1)
    assert_equal(leaf2, tree.root.childs[2])
    leaf3 = get_next_leaf(leaf2)
    assert_equal(leaf3, tree.root.childs[3])
    assert_equal(get_next_leaf(leaf3), nil)

    #             [6]
    #     [4]              [10,25]
    # [1,2] [4,5]    [6,7,8] [10,20] [25,26,100]
    insert!(tree, 25, 26)
    leaf0 = get_first_leaf(tree)
    assert_equal(leaf0, tree.root.childs[0].childs[0])
    leaf1 = get_next_leaf(leaf0)
    assert_equal(leaf1, tree.root.childs[0].childs[1])
    leaf2 = get_next_leaf(leaf1)
    assert_equal(leaf2, tree.root.childs[1].childs[0])
    leaf3 = get_next_leaf(leaf2)
    assert_equal(leaf3, tree.root.childs[1].childs[1])
    leaf4 = get_next_leaf(leaf3)
    assert_equal(leaf4, tree.root.childs[1].childs[2])
    assert_equal(get_next_leaf(leaf4), nil)

    #             [6]
    #     [4]              [10,25,27]
    # [1,2] [4,5]    [6,7,8] [10,20] [25,26] [27,28,100]
    insert!(tree, 27, 28)
    leaf0 = get_first_leaf(tree)
    assert_equal(leaf0, tree.root.childs[0].childs[0])
    leaf1 = get_next_leaf(leaf0)
    assert_equal(leaf1, tree.root.childs[0].childs[1])
    leaf2 = get_next_leaf(leaf1)
    assert_equal(leaf2, tree.root.childs[1].childs[0])
    leaf3 = get_next_leaf(leaf2)
    assert_equal(leaf3, tree.root.childs[1].childs[1])
    leaf4 = get_next_leaf(leaf3)
    assert_equal(leaf4, tree.root.childs[1].childs[2])
    leaf5 = get_next_leaf(leaf4)
    assert_equal(leaf5, tree.root.childs[1].childs[3])
    assert_equal(get_next_leaf(leaf5), nil)

    #                       [6,12]
    #     [4]              [10]                  [25,27]
    # [1,2] [4,5]    [6,7,8] [10,11]      [12,13,20] [25,26] [27,28,100]
    insert!(tree, 11, 12, 13)
    leaf0 = get_first_leaf(tree)
    assert_equal(leaf0, tree.root.childs[0].childs[0])
    leaf1 = get_next_leaf(leaf0)
    assert_equal(leaf1, tree.root.childs[0].childs[1])
    leaf2 = get_next_leaf(leaf1)
    assert_equal(leaf2, tree.root.childs[1].childs[0])
    leaf3 = get_next_leaf(leaf2)
    assert_equal(leaf3, tree.root.childs[1].childs[1])
    leaf4 = get_next_leaf(leaf3)
    assert_equal(leaf4, tree.root.childs[2].childs[0])
    leaf5 = get_next_leaf(leaf4)
    assert_equal(leaf5, tree.root.childs[2].childs[1])
    leaf6 = get_next_leaf(leaf5)
    assert_equal(leaf6, tree.root.childs[2].childs[2])
    assert_equal(get_next_leaf(leaf6), nil)
  end

  def test_fix_next_leaf_links
    tree = Tree.new(Leaf.new(10))
    tree2 = Tree.new(Leaf.new(10))
    assert(get_next_leaf(tree.root) == nil)
    assert(get_first_leaf(tree) == tree.root)
    fix_next_leaf_links!(tree)
    assert(get_next_leaf(tree.root) == nil)
    assert(get_first_leaf(tree) == tree.root)
    assert_equal(tree, tree2)

    #      10
    # [1,5] [10,20,100]
    tree = Tree.new(Internal.new([10], [Leaf.new(1, 5), Leaf.new(10, 20, 100)]))
    fix_parents!(tree)
    fix_next_leaf_links!(tree)
    insert!(tree2, 20, 5, 100, 1)
    assert_equal(tree, tree2)

    #       [4,10]
    # [1,2] [4,5,6] [10,20,100]
    tree = Tree.new(Internal.new(
      [4,10], [Leaf.new(1,2), Leaf.new(4,5,6), Leaf.new(10,20,100)]))
    fix_parents!(tree)
    fix_next_leaf_links!(tree)
    insert!(tree2, 2, 6, 4)
    assert_equal(tree, tree2)

    #       [4,6,10]
    # [1,2] [4,5] [6,7,8] [10,20,100]
    tree = Tree.new(Internal.new(
      [4,6,10],
      [Leaf.new(1,2), Leaf.new(4,5), Leaf.new(6,7,8), Leaf.new(10,20,100)]))
    fix_parents!(tree)
    fix_next_leaf_links!(tree)
    insert!(tree2, 7, 8)
    assert_equal(tree, tree2)

    #             [6]
    #     [4]              [10,25]
    # [1,2] [4,5]    [6,7,8] [10,20] [25,26,100]
    tree = Tree.new(
      Internal.new([6],
        [Internal.new([4], [Leaf.new(1,2), Leaf.new(4, 5)]),
         Internal.new([10,25], [Leaf.new(6,7,8), Leaf.new(10,20), Leaf.new(25,26,100)])]))
    fix_parents!(tree)
    fix_next_leaf_links!(tree)
    insert!(tree2, 25, 26)
    assert_equal(tree, tree2)

    #             [6]
    #     [4]              [10,25,27]
    # [1,2] [4,5]    [6,7,8] [10,20] [25,26] [27,28,100]
    tree = Tree.new(
      Internal.new([6],
        [Internal.new([4], [Leaf.new(1,2), Leaf.new(4, 5)]),
         Internal.new([10,25,27], [Leaf.new(6,7,8), Leaf.new(10,20), Leaf.new(25,26), Leaf.new(27,28,100)])]))
    fix_parents!(tree)
    fix_next_leaf_links!(tree)
    insert!(tree2, 27, 28)
    assert_equal(tree, tree2)

    #                       [6,12]
    #     [4]              [10]                  [25,27]
    # [1,2] [4,5]    [6,7,8] [10,11]      [12,13,20] [25,26] [27,28,100]
    tree = Tree.new(
      Internal.new([6,12],
        [Internal.new([4], [Leaf.new(1,2), Leaf.new(4, 5)]),
         Internal.new([10], [Leaf.new(6,7,8), Leaf.new(10,11)]),
         Internal.new([25,27], [Leaf.new(12,13,20), Leaf.new(25,26), Leaf.new(27,28,100)])]))
    fix_parents!(tree)
    fix_next_leaf_links!(tree)
    insert!(tree2, 11, 12, 13)
    assert_equal(tree, tree2)
  end
end

def get_first_leaf(tree)
  return get_first_leaf_helper(tree.root)
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
  # go up the necessary amount
  node = leaf
  descend_from = nil
  while !node.parent.nil?
    i = 0
    while i < node.parent.childs.size()
      if node.parent.childs[i] == node
        break
      end
      i += 1
    end
    assert(i < node.parent.childs.size())

    if i+1 < node.parent.childs.size()
      descend_from = node.parent.childs[i+1]
      break
    end

    node = node.parent
  end
  if descend_from.nil?
    return nil
  end

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
  tree.root.parent = nil
  fix_parents_helper!(tree.root)
end

# Assume this node and everything above it have correct parent set.
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
  while leaf != nil
    nleaf = get_next_leaf(leaf)
    leaf.next_leaf = nleaf
    leaf = nleaf
  end
end

def fix_tree!(tree)
  fix_parents!(tree)
  fix_next_leaf_links!(tree)
end

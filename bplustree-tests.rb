require 'test/unit'
require 'tempfile'
require_relative 'bplustree'

class Tests < Test::Unit::TestCase
  def test_0
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
    assert_equal(tree, tree2)
  end
end


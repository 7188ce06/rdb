require 'test/unit'
require 'tempfile'
require_relative 'main'

class Tests < Test::Unit::TestCase
  def test_0
    t = Tempfile.create('foo', './tmp/')
    pool = PagePool.new(t.path, 3)
    f1 = pool.fetchPage(0)
    f2 = pool.fetchPage(0)
    f3 = pool.fetchPage(1)
    assert_equal(f1.object_id, f2.object_id)
    refute_equal(f1.object_id, f3.object_id)
    assert_equal(pool.frames_map, {0 => 0, 1 => 1})
    assert_equal(pool.fifo_list, [0, 1])
    assert_equal(pool.free_list, [2])
  end

  def test_1
    t = Tempfile.create('foo', './tmp/')
    pool = PagePool.new(t.path, 2)

    f1 = pool.fetchPage(0)
    pool.unpinPage(0, false)

    f2 = pool.fetchPage(0)
    assert_equal(f1.object_id, f2.object_id)
    assert_equal({ 0 => 0 }, pool.frames_map)
  end

  def test_2
    t = Tempfile.create('foo', './tmp/')
    pool = PagePool.new(t.path, 1)

    f = pool.newPage()
    f.data[0] = 'Q'
    pool.unpinPage(f.pid, true)

    pool.fetchPage(f.pid+1)
    assert_equal(readPage(pool.dbfile, f.pid)[0], 'Q')
  end

  def test_3
    t = Tempfile.create('foo', './tmp/')
    pool = PagePool.new(t.path, 1)
    f1 = pool.fetchPage(0)
    assert_raises(RuntimeError) do
      pool.fetchPage(1)
    end
  end

  def test_4_flush_page_persists_and_clears_dirty
    t = Tempfile.create('foo', './tmp/')
    pool = PagePool.new(t.path, 2)

    f = pool.newPage
    pid = f.pid
    f.data[0] = 'X'
    pool.unpinPage(pid, true)

    assert_equal(true, f.dirty)
    assert_equal("\0", readPage(pool.dbfile, pid)[0])
    pool.flush_page(pid)
    assert_equal(false, f.dirty)
    assert_equal('X', readPage(pool.dbfile, pid)[0])
  end

  def test_5_flush_all_persists_multiple_pages
    t = Tempfile.create('foo', './tmp/')
    pool = PagePool.new(t.path, 3)

    f0 = pool.newPage
    f1 = pool.newPage

    f0.data[0] = 'A'
    f1.data[0] = 'B'
    pool.unpinPage(f0.pid, true)
    pool.unpinPage(f1.pid, true)

    assert_equal("\0", readPage(pool.dbfile, f0.pid)[0])
    assert_equal("\0", readPage(pool.dbfile, f1.pid)[0])
    pool.flush_all
    assert_equal('A', readPage(pool.dbfile, f0.pid)[0])
    assert_equal('B', readPage(pool.dbfile, f1.pid)[0])
  end

  def test_6_new_page_ids_are_monotonic_and_unique
    t = Tempfile.create('foo', './tmp/')
    pool = PagePool.new(t.path, 2)

    f0 = pool.newPage
    pool.unpinPage(f0.pid, true)

    f1 = pool.newPage
    pool.unpinPage(f1.pid, true)

    assert_equal(f0.pid + 1, f1.pid)
  end
end

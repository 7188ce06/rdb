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

class TablePageTests < Test::Unit::TestCase
  def test_0
    x = "A".b*PAGE_SIZE
    tp_init!(x, 50)
    assert_equal(tp_next_page_id(x), 50)
    tp_set_next_page_id!(x, 69)
    assert_equal(tp_next_page_id(x), 69)
  end

  def test_1
    x = "\0".b*PAGE_SIZE
    tp_init!(x, 1)
    tp1 = Tuple.new(3, 33)
    tp2 = Tuple.new(8, 88)
    tp3 = Tuple.new(4, 44)
    assert_equal(tp_insert_tuple!(x, tp1), 0)
    assert_equal(tp_insert_tuple!(x, tp2), 1)
    assert_equal(tp_insert_tuple!(x, tp3), 2)
    (slot_count, tuples_start, next_pid) = x[0..7].unpack("nnN")
    assert_equal(slot_count, 3)
    assert_equal(tuples_start, PAGE_SIZE-24)
    assert_equal(next_pid, 1)
    (s1_start, s1_size, s2_start, s2_size, s3_start, s3_size) = x[8, 12].unpack("nnnnnn")
    assert_equal(s1_start, PAGE_SIZE-8)
    assert_equal(s1_size, 8)
    assert_equal(Tuple.dec(x[s1_start, s1_size]), tp1)
    assert_equal(tp_get_tuple(x, 0), tp1)
    assert_equal(s2_start, PAGE_SIZE-16)
    assert_equal(s2_size, 8)
    assert_equal(Tuple.dec(x[s2_start, s2_size]), tp2)
    assert_equal(tp_get_tuple(x, 1), tp2)
    assert_equal(s3_start, PAGE_SIZE-24)
    assert_equal(s3_size, 8)
    assert_equal(Tuple.dec(x[s3_start, s3_size]), tp3)
    assert_equal(tp_get_tuple(x, 2), tp3)

    xs = []
    tp_each_tuple(x) do |t|
      xs.append(t)
    end
    assert_equal(xs, [tp1, tp2, tp3])
  end
end

class TableHeapTests < Test::Unit::TestCase
  def test_foo
    t = Tempfile.create('foo', './tmp/')
    pool = PagePool.new(t.path, 3)

    theap = TableHeap.new(pool, true)
    tp1 = Tuple.new(1, 2)
    tp2 = Tuple.new(9, 20)
    tp3 = Tuple.new(55, 100)
    r = theap.insert(tp1)
    assert_equal(r.pid, 0)
    assert_equal(r.slot_id, 0)
    theap.insert(tp2)
    theap.insert(tp3)
    f0 = theap.pool.fetchPage(0)
    tp_set_next_page_id!(f0.data, 1)
    theap.pool.unpinPage(f0.pid, true)
    f1 = theap.pool.newPage()
    tp_init!(f1.data, nil)
    theap.pool.unpinPage(f1.pid, true)
    tp4 = Tuple.new(8, 20)
    tp5 = Tuple.new(22, 69)
    tp6 = Tuple.new(1000, 2000)
    r = theap.insert(tp4)
    assert_equal(r.pid, 1)
    assert_equal(r.slot_id, 0)
    theap.insert(tp5)
    theap.insert(tp6)

    assert_equal(theap.get(RecordID.new(0, 0)), tp1)
    assert_equal(theap.get(RecordID.new(0, 1)), tp2)
    assert_equal(theap.get(RecordID.new(0, 2)), tp3)
    assert_equal(theap.get(RecordID.new(1, 0)), tp4)
    assert_equal(theap.get(RecordID.new(1, 1)), tp5)
    assert_equal(theap.get(RecordID.new(1, 2)), tp6)
  end

  def test_bar
    t = Tempfile.create('foo', './tmp/')
    pool = PagePool.new(t.path, 3)
    theap = TableHeap.new(pool, true)

    # 4096 - 8 = 4088 (8 bytes for header)
    # 4088 / (8 + 4) = 340r8 (8 for each tuple and 4 for its directory entry)

    i = 0
    while i < 340
      rid = theap.insert(Tuple.new(i, 2*i))
      assert_equal(rid.pid, 0)
      assert_equal(rid.slot_id, i)
      i += 1
    end

    rid = theap.insert(Tuple.new(i, 3*i+1))
    assert_equal(rid.pid, 1)
    assert_equal(rid.slot_id, 0)

    xs = []
    theap.scan do |tpl|
      xs.append(tpl)
    end
    i = 0
    while i < 340
      assert_equal(xs[i], Tuple.new(i, 2*i))
      i += 1
    end
    assert_equal(xs[i], Tuple.new(i, 3*i+1))
  end
end

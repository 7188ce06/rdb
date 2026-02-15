PAGE_SIZE = 4096

##### low level disk access
def readPage(dbfile, i)
  dbfile.seek(PAGE_SIZE*i, IO::SEEK_SET)
  x = dbfile.read(PAGE_SIZE) || +"".b
  return x + "\0".b*(PAGE_SIZE - x.bytesize())
end

def writePage(dbfile, i, xs)
  raise "error" if xs.bytesize != PAGE_SIZE
  dbfile.seek(PAGE_SIZE*i, IO::SEEK_SET)
  dbfile.write(xs)
  dbfile.flush()
end

# return next available page id
def allocatePage(dbfile)
  dbfile.size / PAGE_SIZE
end

Frame = Struct.new(:pid, :data, :pin_count, :dirty)

class PagePool
  attr_reader :frames_map, :fifo_list, :free_list, :dbfile

  def initialize(filepath, psize)
    @dbfile = File.open(filepath, File::RDWR | File::CREAT)
    @dbfile.binmode()

    @frames = []
    @frames_map = {}
    @free_list = 0.upto(psize-1).to_a
    @fifo_list = []
    @next_pid = @dbfile.size / PAGE_SIZE
  end

  # XXX: Maybe this shouldn't simulate 'newPage'.  Otherwise, how am I ensuring
  #      that @next_pid is correct?
  def fetchPage(pid)
    i = @frames_map[pid]
    if !i.nil?
      @frames[i].pin_count += 1
      return @frames[i]
    else
      j = @free_list.first()
      if !j.nil?
        @frames[j] = Frame.new(pid, readPage(@dbfile, pid), 1, false)
        @frames_map[pid] = j
        @fifo_list.append(j)
        @free_list.delete(j)
        return @frames[j]
      else
        k = @fifo_list.find {|k| @frames[k].pin_count == 0}
        if !k.nil?
          if @frames[k].dirty == true
            writePage(@dbfile, @frames[k].pid, @frames[k].data)
          end
          @frames_map.delete(@frames[k].pid)
          @fifo_list.delete(k)

          @frames[k] = Frame.new(pid, readPage(@dbfile, pid), 1, false)
          @frames_map[pid] = k
          @fifo_list.append(k)
          return @frames[k]
        else
          raise "No available frames."
        end
      end
    end
  end

  # XXX: The handling of #dirty might be wrong.  Shouldn't consumers just
  #      update @dirty after they make a change?
  def unpinPage(pid, dirty)
    i = @frames_map[pid]
    f = @frames[i]
    f.dirty = f.dirty || dirty
    f.pin_count -= 1
  end

  def newPage()
    i = @free_list.first()
    if !i.nil?
      pid = @next_pid
      @next_pid += 1
      @frames[i] = Frame.new(pid, "\0".b*PAGE_SIZE, 1, true)
      @frames_map[pid] = i
      @fifo_list.append(i)
      @free_list.delete(i)
      return @frames[i]
    else
      j = @fifo_list.find {|j| @frames[j].pin_count == 0}
      if !j.nil?
        if @frames[j].dirty == true
          writePage(@dbfile, @frames[j].pid, @frames[j].data)
        end
        @frames_map.delete(@frames[j].pid);
        @fifo_list.delete(j);

        pid = @next_pid
        @next_pid += 1
        @frames[j] = Frame.new(pid, "\0".b*PAGE_SIZE, 1, true)
        @frames_map[pid] = j
        @fifo_list.append(j)

        return @frames[j]
      else
        raise "No available frames."
      end
    end
  end

  def flush_page(pid)
    i = @frames_map[pid]
    if !i.nil?
      f = @frames[i]
      if f.dirty
        writePage(@dbfile, f.pid, f.data)
        f.dirty = false
      end
    end
  end

  def flush_all
    @frames_map.each do |(pid,frame_index)|
      if @frames[frame_index].dirty
        writePage(@dbfile, @frames[frame_index].pid, @frames[frame_index].data)
        @frames[frame_index].dirty = false
      end
    end
  end
end

SLOT_DIR_ELT_SIZE = 4

def tp_init!(page, next_page_id)
  if next_page_id == nil
    next_page_id = (2**32)-1
  end
  page[0..7] = [0, PAGE_SIZE, next_page_id].pack("nnN")
end

def tp_next_page_id(page)
  (x, y, z) = page[0..7].unpack("nnN")
  if z == (2**32)-1
    return nil
  else
    return z
  end
end

def tp_set_next_page_id!(page, pid)
  if pid == nil
    pid = (2**32)-1
  end

  (x,y,z) = page[0..7].unpack("nnN")
  page[0..7] = [x,y,pid].pack("nnN")
end

# Update header.slot_count, header.tuples_start
# Add entry to slot directory
# Add the tuple to the page
def tp_insert_tuple!(page, tuple)
  (slot_count, tuples_start, next_pid) = page[0..7].unpack("nnN")
  slot_dir_start = 8
  next_slot_dir = slot_dir_start + slot_count * SLOT_DIR_ELT_SIZE

  new_tuple_start = tuples_start - tuple.bytesize()
  if next_slot_dir + SLOT_DIR_ELT_SIZE > new_tuple_start
    return nil
  end

  page[next_slot_dir, 4] = [new_tuple_start, tuple.bytesize()].pack("nn")
  page[new_tuple_start, tuple.bytesize()] = tuple
  page[0..7] = [slot_count+1,new_tuple_start,next_pid].pack("nnN")

  return slot_count
end

def tp_get_tuple(page, slot_id)
  (slot_count, tuples_start, next_pid) = page[0..7].unpack("nnN")
  slot_dir_start = 8
  (toffset, tlen) = page[slot_dir_start + slot_id*SLOT_DIR_ELT_SIZE, 4].unpack("nn")
  return page[toffset, tlen]
end

def tp_each_tuple(page, &block)
  (slot_count, tuples_start, next_pid) = page[0..7].unpack("nnN")
  slot_dir_start = 8
  i = 0
  while i < slot_count
    (toffset, tlen) = page[slot_dir_start + i*SLOT_DIR_ELT_SIZE, 4].unpack("nn")
    block.call(page[toffset, tlen])
    i += 1
  end
end

class TableHeap
  attr_reader :pool

  def initialize(pool, new)
    @pool = pool
    if new
      x = @pool.newPage()
      tp_init!(x.data, nil)
      @pool.unpinPage(x.pid, true)
    end
  end

  def insert(tuple)
    frame = @pool.fetchPage(0)
    npid = tp_next_page_id(frame.data)
    while npid != nil
      @pool.unpinPage(frame.pid, false)

      frame = @pool.fetchPage(npid)
      npid = tp_next_page_id(frame.data)
    end

    slot_id = tp_insert_tuple!(frame.data, tuple)
    if !slot_id.nil?
      @pool.unpinPage(frame.pid, true)
      return [frame.pid, slot_id]
    else
      np = @pool.newPage()
      tp_init!(np.data, nil)
      slot_id = tp_insert_tuple!(np.data, tuple)
      tp_set_next_page_id!(frame.data, np.pid)
      @pool.unpinPage(frame.pid, true)
      @pool.unpinPage(np.pid, true)
      return [np.pid, slot_id]
    end
  end

  def get(pid, slot_id)
    frame = @pool.fetchPage(pid)
    t = tp_get_tuple(frame.data, slot_id)
    @pool.unpinPage(frame.pid, false)
    return t
  end

  def scan(&block)
    frame = @pool.fetchPage(0)
    npid = tp_next_page_id(frame.data)
    tp_each_tuple(frame.data) {|t| block.call(t)}
    @pool.unpinPage(frame.pid, false)
    while npid != nil
      frame = @pool.fetchPage(npid)
      npid = tp_next_page_id(frame.data)
      tp_each_tuple(frame.data) {|t| block.call(t)}
      @pool.unpinPage(frame.pid, false)
    end
  end
end

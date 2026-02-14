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

module Dvi::Util
  def read_uint1
    readbyte
  end

  def read_uint2
    (readbyte << 8) | readbyte
  end

  def read_uint3
    (readbyte << 16) | read_uint2
  end

  def read_uint4
    (readbyte << 24) | read_uint3
  end

  def read_int1
    ui = read_uint1
    ui & 128 != 0 ? ui - 256 : ui
  end

  def read_int2
    ui = read_uint2
    ui & 32768 != 0 ? ui - 65536  : ui
  end

  def read_int3
    ui = read_uint3
    ui & 8388608 != 0 ? ui - 16777216 : ui
  end

  def read_int4
    ui = read_uint4
    ui & 2147483648 != 0 ? ui - 4294967296  : ui
  end

  def write_uint4(unum)
      ubyte = Array.new()
     (0..3).each{|i| 
       ubyte[i] = (unum % 256) 
       unum /= 256 
      }
     putc ubyte[3]
     putc ubyte[2]
     putc ubyte[1]
     putc ubyte[0]
   end

  def write_uint3(unum)
     ubyte = Array(3)
     (0..2).each{|i| 
       ubyte[i] = (unum % 256) 
       unum /= 256 
      }
     putc ubyte[2]
     putc ubyte[1]
     putc ubyte[0]
  end

  def write_uint2(unum)
     ubyte = Array(2)
     (0..1).each{|i| 
       ubyte[i] = (unum % 256) 
       unum /= 256 
      }
     putc ubyte[1]
     putc ubyte[0]
  end
  
  def write_uint1(unum)
   putc unum
  end

end

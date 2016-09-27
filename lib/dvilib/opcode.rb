module Dvi::Opcode
  class Error < StandardError; end
  class NotImplemented < StandardError; end

  # Base is a super class for all Opcode classes.
  class Base
    # Sets the range of opcode byte.
    def self.set_range(r)
      if r.kind_of?(Range)
        @range = r
      else
        @range = r..r
      end
    end

    # Returns the range of opcode byte.
    def self.range
      return @range
    end

    def self.read(cmd, io) #:nodoc:
      return self.new
    end

    def interpret(ps) #:nodoc:
      raise NotImplemented, self
    end

   def opcode_mnr(size)
     size = size.abs
     return 1 if size < 2**7
     return 2 if size < 2**15
     return 3 if size < 2**23
     return 4 if size < 2**31
     return 0
   end

   def opcode_fnr(size)
     size = size.abs
     return 4 if size > 2**24
     return 1 if size <= 2**8
     return 2 if size <= 2**16
     return 3 if size <= 2**24
     return 0
   end

   def opcode_fdnr(size)
     size = size.abs
     return 4 if size > 2**24
     return 1 if size < 2**8
     return 2 if size < 2**16
     return 3 if size < 2**24
     return 0
   end


   def opcode_snr(size)
     size = size.abs
     ksize = 254
     return 4 if size >= ksize
     return 1 if size < ksize
   end

  end

  # SetChar is a class for set_char_0 ... set_char_127 opcodes.
  class SetChar < Base
    set_range 0..127
    attr_reader :index

    # index:: character index
    def initialize(index)
      raise ArgumentError unless 0 <= index && index < 256
      @index = index
#      @index = index.chr
    end

    def self.read(cmd, io) #:nodoc:
      return self.new(cmd)
    end

    # Appends a character and changes the current position.
    def interpret(ps)
      # append a new character
      ps.chars << char = Dvi::TypesetCharacter.new(@index, ps.h, ps.v, ps.font)
      # change the current position
      unless self.kind_of?(Put)
        ps.h += ps.font.design_size * char.metric.width
      end
    end

    def to_dt
      return @index
    end 
   
    def uni
      $currpointer += 1
      return self
    end
    
    def to_dv(io)
      opcode = @index
      io.write_uint1(opcode)
      return 1 
    end

  end

  # PrintChar is a base class for set/put opcodes.
  class SetPutBase < SetChar

    # index:: character index
    # n:: read byte length
    def initialize(index, n)
      if case n
         when 1; 0 <= index && index < 256
         when 2; 0 <= index && index < 65536
         when 3; 0 <= index && index < 16777216
         when 4; -2147483648 <= index && index < 2147483648
         end
      then
        @index = index
      else
        raise ArgumentError, [index, n]
      end
    end

    def self.read(cmd, io) #:nodoc:
      base = if self == Set then 127 else 132 end
      n = cmd - base
      f = if n < 4 then "read_uint" + n.to_s else "read_int4" end
      return self.new(io.__send__(f), n)
    end
  end

  # Set is a class for set1 ... set4 opcodes.
  class Set < SetPutBase
    set_range 128..131

    def to_dt
        opnr = opcode_fnr(@index)
        return "s#{opnr} #{@index}"
    end 

    def uni
      opcode = 127
      base = opcode_fnr(@index)
      opcode += base
     
      $currpointer += 1 + base
      return self
    end

    def to_dv(io)
      opcode = 127
      base = opcode_fnr(@index)
      opcode += base
      io.write_uint1(opcode)
      io.__send__("write_uint" + base.to_s, @index)
      return 1 + base 
    end 

  end

  # Put is a class for put1 ... put4 opcodes.
  class Put < SetPutBase
    set_range 133..136

    def to_dt
      return @index.chr 
    end 

  end

  # RuleBase is a base class for SetRule/PutRule opcodes.
  class RuleBase < Base
    attr_reader :height, :width

    def initialize(height, width)
      unless (-2147483648..2147483647).include?(height) and
          (-2147483648..2147483647).include?(width)
        raise ArgumentError
      end

      @height = height
      @width = width
    end

    def self.read(cmd, io)
      return self.new(io.read_int4, io.read_int4)
    end

    def interpret(ps)
      # append a new rule.
      ps.rules << rule = Dvi::Rule.new(ps.h, ps.v, @height, @width)
      # change the current position.
      ps.h += @width unless self.kind_of?(PutRule)
    end
  end

  # SetRule is a class for set_rule opcode.
  class SetRule < RuleBase
    set_range 132
   
    def to_dt
      return "sr #{@height} #{@width}"
    end
 
    def uni
      $currpointer += 1 + 4 + 4
      return self
    end

    def to_dv(io)
      opcode = 132
      io.write_uint1(opcode)
      io.write_uint4(@height)
      io.write_uint4(@width)

      return 1 + 4 + 4
    end
  end

  # PutRule is a class for put_rule opcode.
  class PutRule < RuleBase
    set_range 137

    def to_dt
      return "pr #{@height} #{@width}"
    end

    def uni
      $currpointer += 1 + 4 + 4
      return self
    end

    def to_dv(io)
    opcode = 137
      io.write_uint1(opcode)
      io.write_uint4(@height)
      io.write_uint4(@width)

    return 1 + 4 + 4
    end

  end

  # Nop is a class for nop opcode. The nop opcode means "no operation."
  class Nop < Base
    set_range 138
    # do nothing.
    def interpret(ps); end
    
   def to_dt
     return 'nop'
   end

   def uni
     $currpointer += 1
     return self
   end

   def to_dv(io)
    opcode = 138
    io.write_uint1(opcode)
    return 1 
   end
  end

  # Bop is a class for bop opcode. The bop opcode means "begging of a page."
  class Bop < Base
    set_range 139
    attr_reader :counters, :previous

    def initialize(counters, previous)
      raise ArgumentError if counters.size != 10
      # \count0 ... \count9
      @counters = counters
      # previous bop
      @previous = previous
    end

    def self.read(cmd, io) #:nodoc:
      # read \count0 ... \count9
      counters = (0..9).map{ io.read_int4 }
      # read previous bop position
      previous = io.read_int4
      return self.new(counters, previous)
    end

    def interpret(ps)
      # clear register
      ps.h = 0
      ps.v = 0
      ps.w = 0
      ps.x = 0
      ps.y = 0
      ps.z = 0
      # set the stack empty
      ps.stack.clear
      # set current font to an undefined value
      ps.font = nil
      # !!! NOT IMPLEMENTED !!!
      # Ci?
    end

    def to_dt
      return "bop #{@counters.join(' ')} #{@previous}"
    end

    def uni
     $totalpages += 1
     @previous = $prev_bop
     @counters[0] = $totalpages 
     $prev_bop = $currpointer 
     $currpointer += 1 + 4*10 + 4
     return self
    end 
   
    def to_dv(io)
      opcode = 139
      io.write_uint1(opcode)
      @counters.map{|i| io.write_uint4(i)}
      io.write_uint4($final_bop)
      $final_bop = $fl 
      $total_pages =  $total_pages + 1
      return 1 + 4*10 + 4 
     end
  end

  # Eop is a class for eop opcode. The eop opcode means "end of page."
  class Eop < Base
    set_range 140
    def interpret(ps)
      # the stack should be empty.
      ps.stack.clear
    end

    def to_dt
      return 'eop'
    end
  
    def uni
      $stacklevel = 0
      $currpointer += 1
      return self
    end

    def to_dv(io)
      opcode = 140
      io.write_uint1(opcode)
      return 1
    end
  end

  # Push is a class for push opcode.
  class Push < Base
    set_range 141
    def interpret(ps)
      # push current registry to the stack.
      ps.stack.push([ps.h, ps.v, ps.w, ps.x, ps.y, ps.z])
    end

    def to_dt
      return '['
    end

    def uni
      $stacklevel += 1	
      $stackdepth = $stacklevel if $stackdepth < $stacklevel
      $currpointer += 1
      return self
    end 

    def to_dv(io)
      opcode = 141
      $stack_level = $stack_level + 1
      $stack_depth = [$stack_level,$stack_depth].max
      io.write_uint1(opcode)
      return 1
    end
  end

  # Pop is a class for pop opcode.
  class Pop < Base
    set_range 142
    def interpret(ps)
      # pop the stack and set it to current registry.
      ps.h, ps.v, ps.w, ps.x, ps.y, ps.z = ps.stack.pop
    end
  
    def to_dt
      return ']'
    end

    def uni
        $stacklevel -= 1
        $currpointer += 1
        return self
    end
    
    def to_dv(io)
      opcode = 142
      $stack_level = $stack_level - 1
      io.write_uint1(opcode)      
      return 1 
    end

  end

  class ChangeRegister0 < Base
    def self.read(cmd, io)
      base = case cmd
             when Right.range; 142
             when W.range; 147
             when X.range; 152
             when Down.range; 156
             when Y.range; 161
             when Z.range; 166
             else return self.new
             end
      return self.new(io.__send__("read_int" + (cmd - base).to_s))
    end

      def to_dv(io)
      opcode = case send('class').to_s
               when 'Dvi::Opcode::W0'; 147
               when 'Dvi::Opcode::X0'; 152
               when 'Dvi::Opcode::Y0'; 161
               when 'Dvi::Opcode::Z0'; 166
               end
      io.write_uint1(opcode)
      return 1 
      
      end 

      def uni
        $currpointer += 1
        return self 
      end


  end

  class ChangeRegister < ChangeRegister0
    attr_reader :size

    def initialize(size)
      @size = size
    end
    
      def uni 
        base = opcode_mnr(@size)
        $currpointer += 1 + base
        return self
      end 

      def to_dv(io)
      opcode = case send('class').to_s
               when 'Dvi::Opcode::Right'; 142
               when 'Dvi::Opcode::W'; 147
               when 'Dvi::Opcode::X'; 152
               when 'Dvi::Opcode::Down'; 156
               when 'Dvi::Opcode::Y'; 161
               when 'Dvi::Opcode::Z'; 166
               end
      base = opcode_mnr(@size)
      opcode += base
      io.write_uint1(opcode)
      io.__send__("write_uint" + base.to_s, @size)
      return 1 + base
    end 

      

  end

  # Right is a class for right1 ... right4 opcodes.
  class Right < ChangeRegister
    set_range 143..146
    def interpret(ps)
      # move right.
      ps.h += @size
    end

    def to_dt
      opnr = opcode_mnr(@size)
      return "r#{opnr} #{@size}"
    end
  end

  # W0 is a class for w0 opcode.
  class W0 < ChangeRegister0
    set_range 147
    def interpret(ps)
      # move right.
      ps.h += ps.w
    end

    def to_dt
      return 'w0'
    end
  end

  # W is a class for w1 ... w4 opcodes.
  class W < ChangeRegister
    set_range 148..151
    def interpret(ps)
      # change w.
      ps.w = @size
      # move right.
      ps.h += @size
    end

   def to_dt
     opnr = opcode_mnr(@size)
     return "w#{opnr.to_s} #{@size.to_s}"
   end
  end

  # X0 is a class for x0 opcode.
  class X0 < ChangeRegister0
    set_range 152
    def interpret(ps)
      # move right.
      ps.h += ps.x
    end

    def to_dt
      return 'x0'
    end
  end

  # X is a class for x1 ... x4 opcodes.
  class X < ChangeRegister
    set_range 153..156
    def interpret(ps)
      # change x.
      ps.x = @size
      # move right.
      ps.h += ps.x
    end

    def to_dt
      opnr = opcode_mnr(@size)
      return 'x' + opnr.to_s + ' ' + @size.to_s
    end

  end

  # Down is a class for down1 ... down4 opcodes.
  class Down < ChangeRegister
    set_range 157..160

    def interpret(ps)
      # move down.
      ps.v += @size
    end

    def to_dt
      opnr = opcode_mnr(@size)
      return "d#{opnr} #{@size}"
    end
    
  end

  # Y0 is a class for y0 opcode.
  class Y0 < ChangeRegister0
    set_range 161
    def interpret(ps)
      # move down.
      ps.v += ps.y
    end

    def to_dt
      return 'y0'
    end
  end

  # Y is a class for y1 ... y4 opcodes.
  class Y < ChangeRegister
    set_range 162..165
    def interpret(ps)
      # change y.
      ps.y = @size
      # move down.
      ps.v += @size
    end

    def to_dt
      opnr = opcode_mnr(@size)
      return 'y' + opnr.to_s + ' ' + @size.to_s
    end
  end

  # Z0 is a class for z0 opcode.
  class Z0 < ChangeRegister0
    set_range 166

    # Moves down processor's z.
    def interpret(ps)
      ps.v += ps.z
    end

    def to_dt
      return 'z0'
    end
  end

  # Z is a class for z1 ... z4 opcode.
  class Z < ChangeRegister
    set_range 167..170

    # Changes processor's z and moves down z.
    def interpret(ps)
      # change z.
      ps.z = @size
      # move down.
      ps.v += @size
    end

    def to_dt
      opnr = opcode_mnr(@size)
      return 'z' + opnr.to_s + ' ' + @size.to_s
    end
  end

  # FunNum is a class for fnt_num_0 ... fnt_num_63 opcodes.
  class FntNum < Base
    set_range 171..234
    attr_reader :index
    attr_writer :index

    def initialize(index)
      raise ArgumentError unless 0 <= index && index <= 63
      @index = index
    end

    def self.read(cmd, io)
      return self.new(cmd - 171)
    end

    # Changes the current processor's font.
    # The font should be defined by fnt_def1 .. fnt_def4.
    def interpret(ps)
      raise Error unless ps.fonts.has_key?(@index)
      ps.font = ps.fonts[@index]
    end

    def to_dt
      return "fn#{@index}"
    end

    def uni
      $currpointer += 1
      return self
    end 

    def to_dv(io)
      opcode = 171 + @index
      io.write_uint1(opcode)    
      return 1
    end

  end

  # Fnt is a class for fnt1 ... fnt4 opcodes.
  class Fnt < FntNum
    set_range 235..238
    attr_reader :index
    attr_writer :index

    def initialize(index, n)
      unless case n
         when 1; 0 <= index && index < 256
         when 2; 0 <= index && index < 65536
         when 3; 0 <= index && index < 16777216
         when 4; -2147483648 <= index && index < 2147483648
         else false end
        raise ArgumentError
      end
     @index = index 
    end

    def self.read(cmd, io)
      n = cmd - 234
      f = if n < 4 then "read_uint" + n.to_s else "read_int" + n.to_s end
      return self.new(io.__send__(f), n)
    end

    def to_dt
      opnr = opcode_snr(@index)
      return "f#{opnr} #{@index}"
    end
  
    def uni
        base = opcode_snr(@index)
        $currpointer += 1 + base
        return self
    end

    def to_dv(io)
      opcode = 234
      base = opcode_fdnr(@index)
      opcode += base
      io.write_uint1(opcode)
      io.__send__("write_uint" + base.to_s, @index)
      return 1 + base       
    end
  end

  # XXX is a class for xxx1 ... xxx4 opcodes.
  class XXX < Base
    set_range 239..242
    attr_reader :content
    attr_reader :size

    def initialize(content, n)
      @content = content
      @size = @content.length
    end

    def self.read(cmd, io)
      n = cmd - 238
#      size = buf.__send__("read_uint" + n.to_s)
      size = io.__send__("read_uint" + n.to_s)
      content = io.read(size)
      return self.new(content, n)
    end

    # do nothing
    def interpret(ps); end

    def to_dt
      opnr = opcode_snr(@size)
      return "special#{opnr} #{@size} \'#{@content}\'"
    end
   
    def uni
        base = opcode_snr(@size)
        @size = @content.size
        $currpointer += 1 + base + @size
        return self
    end 

    def to_dv(io)
     opcode = 238
     base = opcode_snr(@size)
     opcode += base 
     io.write_uint1(opcode)
     io.__send__("write_uint" + base.to_s, @size)
     io.print @content
     return 1 + base + @size 
    end

  end

  # FntDef is a class for fnt_def1 ... fnt_def4 opcodes.
  class FntDef < Base
    set_range 243..246
    attr_reader :num, :checksum, :scale, :design_size, :area, :fontname
    attr_writer :num, :checksum, :scale, :design_size, :area, :fontname

    def initialize(num, checksum, scale, design_size, area, fontname)
      @num = num
      @checksum = checksum
      @scale = scale
      @design_size = design_size
      @area = area
      @fontname = fontname
    end

    def self.read(cmd, io)
      n = cmd - 242
      num = if n < 4 then io.__send__("read_uint" + n.to_s) else io.read_int4 end
      checksum = io.read_uint4
      scale = io.read_uint4
      design_size = io.read_int4
      a = io.read_uint1
      l = io.read_uint1
      area = io.read(a)
      fontname = io.read(l)
      return self.new(num, checksum, scale, design_size, area, fontname)
    end

    def interpret(ps)
      aa =  ps.lsr.find(@fontname + ".tfm") 
      tfm = Dvi::Tfm.read(aa) 
      tfm = Dvi::Tfm.read(ps.lsr.find(@fontname + ".tfm"))
      ps.fonts[@num] =
        Dvi::Font.new(@checksum, @scale, @design_size, @area, @fontname, tfm)
    end

    def to_dt
      opnr = opcode_fnr(@num)
      return "fd#{opnr} #{@num} #{@checksum.to_s(8)} #{@scale} #{@design_size} #{@area.size} #{@fontname.size} \'#{@area}\' \'#{@fontname}\'"
    end

    def uni
      base = opcode_fnr(@num)     
      $currpointer += 1 + base + 4 + 4 + 4 + 1 + 1 + @area.size + @fontname.size 
      return self
    end 

    def to_dv(io)
      opcode = 242
      base = opcode_fdnr(@num)
      opcode += base
      io.write_uint1(opcode)
      #num = if n < 4 then io.__send__("read_uint" + n.to_s) else io.read_int4 end
      io.__send__("write_uint" + base.to_s, @num)
      io.write_uint4(@checksum)
      io.write_uint4(@scale)
      io.write_uint4(@design_size)
      io.write_uint1(@area.size)
      io.print @area
      io.write_uint1(@fontname.size)    
      io.print @fontname
      return 1 + base + 4 + 4 + 4 + 1 + 1 + @area.size + @fontname.size 
    end
  end

  # Pre is a class for preamble opcode.
  class Pre < Base
    set_range 247
    attr_reader :version, :num, :den, :mag, :comment
    attr_writer :comment

    def initialize(version, num, den, mag, comment)
      raise ArgumentError unless num > 0 && den > 0 && mag > 0
      @version = version # maybe version is 2
      @num = num         # maybe 25400000 = 254cm
      @den = den         # maybe 473628672 = 7227*(2**16)
      @mag = mag         # mag / 1000
      @comment = comment # not interpreted
    end

    def self.read(cmd, io)
      version = io.read_uint1
      num = io.read_uint4
      den = io.read_uint4
      mag = io.read_uint4
      size = io.read_uint1
      comment = io.read(size)
      return self.new(version, num, den, mag, comment)
    end

    def interpret(ps)
      ps.dvi_version = @version
      ps.numerator = @num
      ps.denominator = @den
      ps.mag = @mag
    end
    
    def to_dt
     return  "pre #{@version} #{@num} #{@den} #{@mag} #{@comment.length} \'#{comment}\'"
    end
   
    def uni
      @num = 25400000
      @den = 473628672
      @version = 2
      @mag = 1000
      $currpointer +=  1 + 1 + 4 + 4 + 4 + 1 + @comment.size 
      return self
    end 

    def to_dv(io)
     opcode = 247
     io.write_uint1(opcode)
     io.write_uint1(@version)
     io.write_uint4(@num)
     io.write_uint4(@den)
     io.write_uint4(@mag)
     io.write_uint1(@comment.size)
     io.print(@comment)
     return 1 + 1 + 4 + 4 + 4 + 1 + @comment.size 
    end
  end

  # Post is a class for post opcode.
  class Post < Base
    set_range 248
    attr_reader :final_bop, :num, :den, :mag, :l, :u, :stack_depth, :total_pages, :pages

    def initialize(pointer, num, den, mag, l, u, stack_depth, total_pages)
      @final_bop = pointer # final bop pointer
      @num = num           # same as preamble
      @den = den           # same as preamble
      @mag = mag           # same as preamble
      @l = l               # height plus depth of the tallest page
      @u = u               # width of the widest page
      @stack_depth = stack_depth # maximum stack depth
      @total_pages = total_pages # total number of pages
    end

    def self.read(cmd, io)
      pointer = io.read_uint4
      num = io.read_uint4
      den = io.read_uint4
      mag = io.read_uint4
      l = io.read_uint4
      u = io.read_uint4
      stack_size = io.read_uint2
      pages = io.read_uint2
      return self.new(pointer, num, den, mag, l, u, stack_size, pages)
    end

    def interpret(ps)
      ps.total_pages = @total_pages
    end

    def to_dt
      return "post #{@final_bop} #{@num} #{@den} #{@mag} #{@l} #{@u} #{@stack_depth} #{@total_pages}"
    end

    def uni
      @num = 25400000
      @den = 473628672
      @mag = 1000
#      @l = 0
#      @u = 0
      @final_bop = $prev_bop
      @stack_depth = $stackdepth
      @total_pages = $totalpages 
      $prev_bop = $currpointer 
      $currpointer += 1 + 4*6 + 2 + 2
      return self
    end
    
    def to_dv(io)
      opcode = 248 
      $final_post = $fl 
      io.write_uint1(opcode)  
      io.write_uint4($final_bop)
      io.write_uint4(@num)
      io.write_uint4(@den)
      io.write_uint4(@mag)
      io.write_uint4(@l)# l are often ignored
      io.write_uint4(@u)# u are often ignored
      io.write_uint2($stack_depth)
      io.write_uint2($total_pages)
      return 1 + 4*6 + 2 + 2
    end


  end

  # PostPost is a class for post_post opcode.
  class PostPost < Base
    set_range 249
    attr_reader :pointer


    def initialize(pointer)
      @pointer = pointer # a pointer to the post command
    end

    def self.read(cmd, io) #:nodoc:
      pointer = io.read_uint4
      dvi_version = io.read_uint1
      # read padding 233
      io.read.unpack("C*").each do |i|
        raise Error unless i == 223
      end
      return self.new(pointer)
    end

    def interpret(ps)
      # ???
    end
   
    def to_dt
      return "post_post #{@pointer} 2 223 223 223 223"
    end

    def uni
        @pointer = $prev_bop
        $currpointer += 10 # doesn't matter anymore
	return self
    end 

   def to_dv(io)
     opcode = 249
     trailing_byte = 223
     dvi_version = 2
     io.write_uint1(opcode)
     io.write_uint4($final_post)
     io.write_uint1(dvi_version)
     io.write_uint1(trailing_byte)
     io.write_uint1(trailing_byte)
     io.write_uint1(trailing_byte)
     io.write_uint1(trailing_byte)
     $fl += 10 # write
     trailing_count = (4 - ($fl % 4)) % 4
     (1..trailing_count).each{ io.write_uint1(trailing_byte) }
     return  10 + trailing_count 
   end
  end

  BASIC_OPCODES = [SetChar, Set, SetRule, Put, PutRule, Nop, Bop, Eop, Push, Pop,
                   Right, W0, W, X0, X, Down, Y0, Y, Z0, Z, FntNum, Fnt, XXX, FntDef,
                   Pre, Post, PostPost]


end

module Dvi

  class Processor
    attr_accessor :h, :v, :w, :x, :y, :z, :font, :fonts
    attr_reader :stack, :chars, :rules, :lsr
    attr_accessor :dvi_version, :numerator, :denominator, :mag
    attr_accessor :total_pages

    def initialize(lsr=Dvi::LsR.default)
      @h = 0 # horizontal position
      @v = 0 # vertical position
      @w = 0 # 
      @x = 0
      @y = 0
      @z = 0
      @font = nil
      @stack = []
      @chars = []
      @rules = []
      @fonts = Hash.new
      @lsr = lsr
    end

    def process(opcode)
      opcode.interpret(self)
    end
  end


  class Unit
    attr_accessor :dvi_version, :numerator, :denominator, :mag, :comment
    attr_accessor :total_pages, :stackdepth, :final_bop
    attr_accessor :opcodetable, :fonttable

    def initialize()
      @opcodetable = Array.new
      @fonttable = Hash.new	
    end

    def proccess(opcode)
      currentfont = ""
      currentstackdepth = 0
      prevbop = 0 
      currentlength = 0 # bytes sum
      opcode.expound(seft, currentfont, currentstackdepth, prevbop, currentlength)
    end 
  end

  class Font
    attr_reader :checksum, :scale, :design_size, :area, :name, :tfm
    def initialize(checksum, scale, design_size, area, name, tfm)
      @checksum = checksum # check sum should be same as in tfm file
      @scale = scale # scale factor
      @design_size = design_size # DVI unit
      @area = area # nil
      @name = name # font name for tfm file
      @tfm = tfm
    end
  end

  # TypesetCharacter is a class of typeset characters.
  class TypesetCharacter
    attr_reader :index, :font, :h , :v, :width
    def initialize(index, h, v, font)
      @font = font
      @h = h
      @v = v
      @index = index
    end

    def metric
      @font.tfm.char[@index]
    end
  end

  # Rule is a class for solid black rectangles.
  class Rule
    attr_reader :height, :width, :h, :v
    def initialize(h, v, height, width)
      @h = h
      @v = v
      @height = height
      @width = width
    end
  end

  # Parse a dvi file as a opcode list.
  def self.parse(io, opcodes = Opcode::BASIC_OPCODES)
    table = Hash.new
    io.extend Util


    opcodes.each do |opcode|
      opcode.range.each{|i|
      table[i] = opcode }
    end

    content = []

    begin
      while cmd = io.readbyte do
        
        content << table[cmd].read(cmd, io)

    end
    
     rescue EOFError
     end

    return content
  end


  def self.process(io, opcodes = Opcode::BASIC_OPCODES)
    ps = Processor.new
    parse(io, opcodes).each do |opcode|
      ps.process(opcode)
    end
    return ps
  end

  def self.to_dt(contents)
     dtcontents = Array.new
     dtcontents << "variety sequences-6"
     text = String.new
     contents.each {|optclass|
     if optclass.class.to_s == "Dvi::Opcode::SetChar" 
       index = optclass.to_dt
#       print index, index.chr, "\n" if index =0

       if index < 32
         dtcontents << "(" +  text + ")" if !text.empty?
         text = '\\0' +  index.to_s(16).upcase if index < 17 
         text = '\\' +  index.to_s(16).upcase if index >= 17
         text = '\00' if index == 0
         text = '\10' if index == 16
         dtcontents << text
         text = ""
       else 
         s = index.chr.to_s
         text << '\\' if index == 40 || index == 41 
	 text << '\\' if index == 92
         text << s 
       end              
     else   
       if !text.empty? 
#         dtcontents << optclass.to_dt
#	 text.gsub!(/\\/){'\\\\'}
         dtcontents << "(" +  text + ")"
         text = ""
        end

      temp = optclass.to_dt
      if optclass.class.to_s == "Dvi::Opcode::XXX"       
        temp.gsub!(/\\/){'\\\\'}
      end 
      dtcontents << temp 

     end
     }
     return dtcontents
  end



 def self.uniform(icontent)
  dcontent = Array.new

  font = nil
  fonts = Hash.new()
  
  posx = 0
  posy = 0
  $stacklevel = 0
  
  $prev_bop = -1
  $currpointer = 0
  $stackdepth = 0
  $totalpages = 0
  


  icontent.each{|op|
   begin
    dcontent << op.uni  
#    puts op.inspect
    rescue =>e
    puts op.inspect
   end 
#    puts $currpointer
  }
  
  return dcontent 
 end

 def self.new
   contents = Array.new
   timestamp = Time.now.strftime("%Y.%m.%d:%H%M")
   contents << Dvi::Opcode::Pre.new(2, 25400000, 473628672, 1000, "Dvi-Ruby output #{timestamp}")
   contents << Dvi::Opcode::Bop.new([1, 0, 0, 0, 0, 0, 0, 0, 0, 0], -1)
   contents << Dvi::Opcode::Eop.new()
   contents << Dvi::Opcode::Post.new(46, 25400000, 473628672, 1000, 41484288, 26673152, 3, 1 )
   contents << Dvi::Opcode::PostPost.new(92)
   return contents
 end

 def self.write(io, contents)
   table = contents
   io.extend Util
   $fl = 0 ## file length
   $stack_level = 0
   $stack_depth = 0
   $total_pages = 0
   $final_bop = -1
   $final_post = 0
   $dvi_version = 0
   table.each{|opclass| $fl += opclass.to_dv(io)
#   print $fl 
#   print " - "
#   print opclass.inspect
#   print "\n"
#   puts opclass.to_dt
   }    
#    puts $fl
   io.close
 end

  def self.diff?(class0, class1)
   return class0.to_dt == class1.to_dt
  end

  def self.pages_length(contents)
   page_i = Hash.new()
   page_s = 0
   page_e = 0
 #  page_c = 0
   contents.reverse_each{|op| 
    if op.class.to_s == "Dvi::Opcode::PostPost" 
     page_e = op.pointer
    end
  
    if op.class.to_s == "Dvi::Opcode::Post" 
     page_s = op.final_bop
    end

    if op.class.to_s == "Dvi::Opcode::Bop" 
       page =  op.counters[0]
       length = page_e - page_s
       page_e = page_s
       page_s = op.previous
       page_i[page] = length
    end
   }

#     p page_i
  return page_i 
  end

  # Compare pages by its length (how much bytes in a page)
  # 
  def self.compare_pages_by_length(icontent, iicontent)
    ipages = Dvi.pages_length(icontent)
    iipages = Dvi.pages_length(iicontent)

    pages_d = Array.new()
      starting_point = [iipages.keys.min, ipages.keys.min].min      
      max_page_length = [ iipages.keys.max - iipages.keys.min, ipages.keys.max - ipages.keys.min].max
#      puts "starting: #{starting_point}"
#      puts "max_page_length: #{max_page_length}"
#      max = [iipages.keys.max, ipages.keys.max].max
      ibase  = ipages.keys.min 
      iibase = iipages.keys.min 
#      min = [iipages.keys.min, ipages.keys.min].min
      ## min = 1 
#      p iipages 
#      p iibase 
      (0..max_page_length).each{|i|
#        puts "i: #{starting_point + i}"
#	puts "iipages[iibase + i] #{iipages[iibase + i]}"
#	puts "ipages[ibase + i] #{ipages[ibase + i]}"
	if ipages[ibase + i] != iipages[iibase + i]
	 if ibase != iibase 
          pages_d << "#{ibase + i}/#{iibase + i}"   
         else 
          pages_d << "#{ibase + i}"      
         end 
        end
        }

       if pages_d.empty?
         puts "No differences found"
       else 
        print "Difference(s) found on page(s): "
        print pages_d.join(", ")
       end	     	
 end

  def self.compare_pages_by_opcode(icontent, iicontent)
    # Not Implemented Yet
  end

 def self.totalpages(icontent)
  icontent.each{|op|
   if op.class.to_s == "Dvi::Opcode::Post"
     return op.total_pages
   end
  }
 end

 def self.split_into_pages(icontent)
  pg = []
  pt = []
  icontent.each{|op|
   next if op.class.to_s == "Dvi::Opcode::Pre"
   next if op.class.to_s == "Dvi::Opcode::Bop"
   if op.class.to_s == "Dvi::Opcode::Eop"
    pg << pt
    pt = []
   end
  if op.class.to_s == "Dvi::Opcode::Post"
   break 
  end
  pt << op
  }
 return pg
 end

 def self.find_fontdefs(icontent)
  fontdef = []
  icontent.reverse_each{|op|
  next  if op.class.to_s == "Dvi::Opcode::PostPost"
  break if op.class.to_s == "Dvi::Opcode::Post" 
  fontdef << op
  }
  return fontdef
 end

 def self.parselayers(icontent, layers)
  body = Array.new()
  lasti = icontent.size-1 
  i = 0
  begin 
  op = icontent[i]
  if op.class == Dvi::Opcode::XXX 
 	puts op.inspect 
    layer = Dvi::Layer.read(op.content,layers)
#	puts layer.inspect 
      if !layer.nil?
      j = 0
      l = []
      l << op
        puts layer.inspect
        puts layer.name
	puts layer.type
	puts layer.etag
      end 

#     puts op.inspect + "is layer"
#     layertype = Dvi::Layer.type(op.content, layers)
#     layeretag = Dvi::Layer.etag(op.content, layers)
#    end 
  else 
   body << op 
  end
   i += 1
  end until i == lasti
  
  return body
 end


end

require 'dvilib/lsr'
require 'dvilib/tfm'
require 'dvilib/util'
require 'dvilib/opcode'
require 'dvilib/version'
require 'dvilib/layer'

module Dvi
  class Layer


    def self.define(larray)
     marray = Array.new()
     larray.each{|l| 
      name = l[0]
      stag = l[1][0]
      etag = l[1][1]
      if etag.nil?
	marray << self::Setup.new(name, stag, nil, 0)
      else
	marray << self::Setup.new(name, stag, etag, 1)
      end
     }

     return marray 
     end 

     def self.islayer?(s, layersetup)
      b = false
      layersetup.each{|l|
      if s =~ /#{l.stag}/
        b = true
      end 
       }
      return b
     end 

    def self.read(s, layersetup)
      l = nil
      layersetup.each{|i| l = i  if s =~ /#{i.stag}/}
      return l 
    end 



    # Unitary (Single) Layer
    class Uni
     attr_accessor :name, :tag, :args

      def initialize(name, tag, args)
        @name = name 
	@tag  = tag
	@args = args
      end 


    end

    # Double (Pair)  Layer
    class Duo
      attr_accessor :name, :stag, :etag, :sargs, :eargs, :body

      def initialize(name, stag, etag, sargs, eargs, body)
	@name = name 
	@stag = stag
	@etag = etag
	@sargs = sargs
	@eargs = eargs
	@body = body
      end 

      def read(name, contents)

      end 
    end 

    class Setup 
     attr_accessor :name,  :stag, :etag, :type
     

     def initialize(name, stag, etag, type)
	@name = name
	@stag = stag
	@etag = etag
	@type = type
     end
    end 

  end 

end

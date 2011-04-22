require 'bloomfilter.rb'
require 'pp'

=begin
	Basic Node functionality
=end

class Node
	# create a global id namespace for convenience tracking. might be
	# problematic if we have a TON of nodes, and note that IDs from nodes that
	# get killed never get re-used. 
	@@id = 0
#	@@bufferMin = nil
#	@@bufferRange = nil
#	@@broadcastRange = nil
#	@@broadcastMin= nil

	def self.setup(broadcastRange, broadcastMin, bufferRange, bufferMin)
		@@broadcastRange = broadcastRange
		@@broadcastMin= broadcastMin
		@@bufferMin = bufferMin
		@@bufferRange = bufferRange
	end

	def initialize
		# instantiate an ID from the global node ID space
		@nid = @@id
		@@id += 1

		@max_buffer = rand(@@bufferRange) + @@bufferMin
		@broadcastRadius = rand(@@broadcastRange) + @@broadcastMin
		@current_buffer = 0
		@buffer = {}
		
		@digest = BloomFilter.new(512, 10) # 512 bits, 10 hash functions
		@neighbors = [] 

		# not exactly sure what we use these for.. something to do with
		# subscriptions instead of LMS items?
		@new_messages = {}
		@cached_messages = {}

		# this calls the initialize method of any included modules. magic
		# happiness! (note that included modules get treated like
		# *super*classes, which is why you don't call super from the module's
		# initialize() method, even though we are including the module IN the
		# class). 
		super
	end
	attr_accessor :nid, :neighbors, :broadcastRadius

#	def ==(other)
#		if @nid == other.nid then 
#			return true
#		else 
#			return false
#		end
#	end

	def updateNeighbors (list)
		# the neighbors being passed in are physical neihgbors. neighbors in the
		# routing overlay may be different.  
		@neighbors = list
	end

	def to_s
		return "Node#{@nid}"
	end

	# Physical Storage Methods
   
	def bufferAdd(k, item)
		# add the item if new or update the item if that key already exists in the
		# buffer
		unless bufferFull?
			if containsKey?(k)
				list = @buffer[k]
				list.push(item)
				@buffer.store(k, list)
			else
				list = []
				list.push(item)
				@buffer.store(k, list)
				@digest.insert(k)
			end
			@current_buffer += 1 
		else
			raise "Max buffer size exceeded"
		end
	end

	def containsKey?(k)
		return @buffer.key?(k)
	end

	def containsData?(item)
		@buffer.each{|key, value|
			value.each{|data|
				if data == item
					return true
				end
			}
		}
		return false
	end

	def bufferFull?
		if @current_buffer >= @max_buffer
			return true
		else
			return false
		end
	end

	def bufferLength()
		return @current_buffer
	end

	def retrieve(k)
		return @buffer[k]
	end

	def digest()
		return @digest
	end

end



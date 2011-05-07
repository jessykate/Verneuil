=begin
	Basic Node functionality
=end

class Node
	# create a global id namespace for convenience tracking. might be
	# problematic if we have a TON of nodes, and note that IDs from nodes that
	# get killed never get re-used. 
	@@id = 0

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

		@broadcastRadius = rand(@@broadcastRange) + @@broadcastMin
		@buffer_size = rand(@@bufferRange) + @@bufferMin
		@buffer = []
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
	attr_accessor :nid, :broadcastRadius
	attr_reader :neighbors

	def update_nbrs=(list)
		# the neighbors being passed in are physical neihgbors. neighbors in the
		# routing overlay may be different.  
		@neighbors = list
	end

	def to_s
		return "Node#{@nid}"
	end

	##########################################
	# Physical Storage Methods
	##########################################
   
	def buffer_store(k, item)
		# add the item if new or update the item if that key already exists in the
		# buffer
		if buffer_full? 
			result = false
			reason = :full
		elsif @buffer.include? [k,item]
			result = false
			reason = :duplicate
		else
			result = true
			reason = nil
			@buffer << [k,item]
		end
		return [result, reason]
	end

	def buffer_full?
		return @buffer.size == @buffer_size || false
	end

	def retrieve(k)
		return @buffer[k]
	end

end



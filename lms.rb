require 'digest/sha1'

=begin
assumes a network object will be passed in which supports the following API:
    network.getNodes(): returns all nodes in the network
    network.neighbors(id): returns all physical neighbours of node with the given id. 

LMS handles replica determination, possibly based on dynamic criteria passed in
from individual publishing nodes.  
=end

module LMS
	@@hops = nil
	@@lambda = nil
	@@max_failures = nil
	@@randomWalkRange = nil
	@@randomWalkMin = nil
	@@reply_ttl = nil

	def self.setup(hops, lambda_, max_failures, randWalkRange, randWalkMin, reply_ttl)
		# set up some class-level variables to specify parameters of this LMS
		# 'install'. call this after including the module to initialize.  
		
		# how many hops should the node consider in its LMS
		# neighborhood?
		@@hops = hops 
		
		# the size of the ID space is 2**lambda
		@@lambda = lambda_ 
		
		# max allowable failures in trying to store an item
		@@max_failures = max_failures 

		# random walk lengths - range and start value
		@@randomWalkRange = randWalkRange
		@@randomWalkMin = randWalkMin

		@@hash_functions = [1, 2, 3, 4, 5]

		# when responding to a message, how long should the message rattle
		# around the network without finding its destination, before being
		# considered lost?
		@@reply_ttl = reply_ttl
	end
	attr_reader :hops, :lambda, :max_failures, :randomWalkRange, :randomWalkMin, :reply_ttl 
	
	# this will get called via super from the including class' initialize
	# method (by construction)
	def initialize()
		@put_failures = {} 
		@hashID= compute_hash(@nid)
		super
	end
	attr_accessor :hashID

	def randWalkLength()
		return rand(@@randomWalkRange) + @@randomWalkMin
	end

	def hash_string
		return @@hash_functions[rand(@@hash_functions.length)].to_s
	end

	def get_init(key, time)
		# assemble THE PROBE
		hash_key = compute_hash(key + hash_string())
		probe = Probe.new(initiator= @nid, key, hash_key, walk_length = randWalkLength(), time)
		# sending to receive_probe first will initialize the random walk
		return receive_probe(probe, time)
	end	

	def put_init(key, item, time, rw= false)
		# assemble THE PROBE
		# if this is a put request with a backoff factor due to failure, rw
		# will contain a length twice the previous length that failed. else,
		# this is a fresh request and a new random walk length is generated. 
		hash_key = compute_hash(key + hash_string())
		probe = PUTProbe.new(item = item, initiator= @nid, key, hash_key, 
							 walk_length = (rw || randWalkLength()), time)
		# save some information about this active request
		@put_failures[key.to_s + item.to_s] = 0 unless @put_failures.keys.include? key.to_s + item.to_s
						
		# sending to receive_probe first will initialize the random walk
		return receive_probe(probe, time)
	end	

	def forward_get_reply(dst, msg, time)
		response = {}
		if msg[:hops] >= @@reply_ttl
			response[:status] = :failure
			response[:error] = :lost
			return response
		end
		probe = msg[:probe]
		# check if this node is the destination...
		if dst == @nid
			# see if it was a failure or success
			if probe.status == :failure
				response[:status] = :failure
				response[:error] = probe.error
				response[:data] = {:probe, probe}
			else
				# uhh... we're done!
				response[:status] = :success
				response[:data] = {:probe, probe}
			end
		else
			# we need to find a smart neighbor to fwd to
			response = smart_forward dst, probe, msg

#			# doesn't really matter if we use random or deterministic choice
#			# here since the nodes are not ordered in any way. but if the
#			# local_min IS this node, but is NOT the destination, then pick a
#			# random nbr instead. 
#			min = local_minimum(dst)
#			min == @nid ? next_hop = @neighbors[rand(@neighbors.length)] : next_hop = min
#			if not min 
#				#if we have no neighbors the message is basically dropped. 
#				response[:status] = :failure
#				probe.error = :isolated
#				response[:data] = {:probe, probe}
#			else
#				response[:status] = :forward
#				new_msg = {:probe, probe, :hops, msg[:hops]+1}
#				response[:data] = {:dst, dst, :msg, new_msg, :next_hop, next_hop}
#			end
		end
		return response
	end

	def forward_put_reply(dst, msg, time)
		response = {}
		if msg[:hops] >= @@reply_ttl
			response[:status] = :failure
			response[:error] = :lost
			return response
		end
		probe = msg[:probe]
		# check if this node is the destination...
		if dst == @nid
			# see if it was a failure or success
			if probe.status == :failure
				@put_failures[probe.orig_key.to_s + probe.item.to_s] += 1
				current_failures = @put_failures[probe.orig_key.to_s + probe.item.to_s]
				if current_failures < @@max_failures
					# will go through put_init which calls receive_probe and
					# then returns back probe object. also note that retries
					# keep the original start time so as to accurately account
					# for the extra time.

					new_probe = put_init(probe.orig_key, probe.item, start_time = probe.start_time, rw = probe.total_walk_length*2)
					response[:status] = :retry
					response[:error] = probe.error
					response[:data] = {:new_probe, new_probe, :old_probe, probe, :next_hop, new_probe.path.last }
				else
					response[:status] = :failure
					response[:error] = probe.error
					response[:data] = {:probe, probe}
				end		
			else
				# uhh... we're done!
				response[:status] = :success
				response[:data] = {:probe, probe}
			end
		else
			# we need to find a smart neighbor to fwd to
			response = smart_forward dst, probe, msg
		end
		return response

#			# doesn't really matter if we use random or deterministic choice
#			# here since the nodes are not ordered in any way. but if the
#			# local_min IS this node, but is NOT the destination, then pick a
#			# random nbr instead. 
#			min = local_minimum(dst)
#			min == @nid ? next_hop = @neighbors[rand(@neighbors.length)] : next_hop = min
#			if not min 
#				#if we have no neighbors the message is basically dropped. 
#				response[:status] = :failure
#				probe.error = :isolated
#				response[:data] = probe
#			else
#				response[:status] = :forward
#				new_msg = {:probe, probe, :hops, msg[:hops]+1}
#				response[:data] = {:dst, dst, :msg, new_msg, :next_hop, next_hop}
#			end
#		end
#		return response
	end

	def smart_forward dst, probe, msg
		response = {}
		if @neighbors.empty?
			#if we have no neighbors the message is basically dropped. 
			response[:status] = :failure
			probe.error = :isolated
			response[:data] = probe
		else
			# try and find the way back to the source by leveraging information
			# in the path. basically, the 'closer' in the path we can get to
			# the source, the better. so slice the probe path wherever this
			# node appears, then search for neighbors `closer' to the source. 
			way_back = [dst]+probe.path[0..(probe.path.index(@nid) || -1)]
			puts "at node #{@nid}"
			puts "neighbors"
			pp @neighbors
			puts "entire path"
			pp probe.path
			puts "way_back"
			pp way_back
			way_back.each {|step| # will start at the goal and back off 
				puts "checking path list for #{step}"
				if @neighbors.include? step
					puts "neighbor list included #{step}"
					gets
					response[:status] = :forward
					new_msg = {:probe, probe, :hops, msg[:hops]+1}
					response[:data] = {:dst, dst, :msg, new_msg, :next_hop, step}
					break
				end
			}
		end
		return response
	end


	def compute_hash(nid)
		d = Digest::SHA1.hexdigest(nid.to_s).hex
		return d.modulo(2**@@lambda)
	end

	def hash_distance(key1, key2)
		# compute the distance between the hashes of the two keys, using the
		# globally agreed upon hash function for this protocol. 
		hash1 = compute_hash(key1)
		hash2 = compute_hash(key2)
		w1 = (@hashID - hash).modulo(2**@@lambda)
		w2 = (hash2 - @hashID).modulo(2**@@lambda)
		if w1 < w2
			return w1
		else
			return w2
		end
	end

	def local_minimum(k)
		# returns the node in the h-hop neighborhood whose hash forms a local
		# minimum with the key to be stored
		min_node = @nid
		min_dist = hash_distance(k, @nid)
		@neighbors.each{|nodeID|
			# distance between key k and the neighbor node
			dist = hash_distance(k, nodeID)
			if dist < min_dist
				min_dist = dist
				min_node = nodeID
			end
		}
		return min_node
	end

	def receive_probe(probe, time)
		# note that this method adds the NEXT node (the node it has chosen) to
		# the probe path, not itself. ('itself' was added by the previous node)
		if probe.random_walk? 
			probe.decrease_steps
			randomNode = @neighbors[rand(@neighbors.length)]
			if not randomNode
				# we have no neighbors. alas. 
				return :isolated
			end
			probe.path << randomNode
		else # deterministic walk
			min_node = local_minimum(probe.key)
			if min_node == @nid
				# only difference between PUT and GET probes is here
				if probe.type == :put
					status, info = buffer_store(probe.key, probe.item)
				else
					status, info = buffer_get(probe.key)
				end

				# bookkeeping and return
				if status == true
					probe.status = :success
					if probe.type == :get
						probe.item = info
					end
				else
					probe.status = :failure
					probe.error = info
				end
				probe.end_time = time
			else
				probe.path << min_node
			end
		end
		return probe
	end

end

class Probe
	def initialize(initiator, key, hash_key, walk_length, start_time)
		@type = :get
		@initiator = initiator
		@key = hash_key
		# the original key, unhashed (this is kind of an ugly hack for when a
		# PUTProbe needs to be retried...shrug.
		@orig_key = key
		# the +1 is sort of a stupid hack since the first 'step' on the random
		# walk is the originating node is itself. should find a better way to
		# do that. 
		@walk_length = walk_length+1
		@total_walk_length = @walk_length
		@start_time = start_time
		# time at which item was deposited/failed
		@end_time = nil
		@path = []
		@status = :outbound
		@error
	end
	attr_accessor :initiator, :path, :walk_length, :status, :error, :end_time
	attr_reader :total_walk_length, :key, :start_time, :type, :orig_key

	def random_walk?
		return @walk_length > 0 || false
	end

	def decrease_steps
		@walk_length -=1
	end

	# for storing any items found during the get request
	def item=(i)
		@item = i
	end

	def item
		return @item
	end

	def to_s
		return "<Probe: item: #{@item}, initiator: #{@initiator}, key: #{@key}, random_walk_length: #{@total_walk_length}, current_walk_length: #{@walk_length}, path: #{path_to_s}, status: #{status}, error: #{error} >"
	end

	def path_to_s
		s = ""
		@path.each{|p|
			s += p.to_s + "->"
		}
		return s.chop.chop
	end

end

class PUTProbe < Probe
  def initialize(item, initiator, key, hash_key, walk_length, start_time)
    super(initiator, key, hash_key, walk_length, start_time)
	@type = :put
    @item = item 
  end

  def to_s
	  return "<Probe: item: #{@item}, initiator: #{@initiator}, key: #{@key}, random_walk_length: #{@total_walk_length}, current_walk_length: #{@walk_length}, path: #{path_to_s}, status: #{status}, error: #{error} >"
  end
end




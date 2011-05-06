require 'digest/sha1'
require 'pp'

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

	def self.setup(hops, lambda_, max_failures, randWalkRange, randWalkMin)
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
	end
	
	# this will get called via super from the including class' initialize
	# method (by construction)
	def initialize()
		@hashID= computeHash(@nid)
		super
	end
	attr_accessor :hashID

	def randWalkLength()
		return rand(@@randomWalkRange) + @@randomWalkMin
	end

	def hash_string
		return @@hash_functions[rand(@@hash_functions.length)].to_s
	end

	def put_init(key, item)
		# assemble THE PROBE
		probe = PUTProbe.new(item = item, initiator= @nid, 
							 key=computeHash(key + hash_string()), 
							 walk_length = randWalkLength(), 
							 path=[], @@max_failures)
		return probe
	end	

	def put(key, item, replicas)
		initiator = @nid
		successes = 0.0
		stats = {}
		(1..replicas).each {|r| 
			hash_string = @@hash_functions[rand(@@hash_functions.length)].to_s
			hash = computeHash(key + hash_string)
			walk_length = randWalkLength()
			probe = PUTProbe.new(item, initiator, hash, walk_length)
			success = false
			give_up = false
			while not success and not give_up
				last_node, probe = random_walk(probe)
				#prevent adding id to path twice        
				probe.pop_last() 
				node = last_node.deterministic_walk(probe)

				if node.bufferFull? or (node.containsKey?(key) and 
										node.containsData?(item)) 
					probe.fail()
					if probe.getFailures >= @@max_failures
						give_up = true
					else
						probe.walk_length = walk_length * 2
						probe.clearPath()
						next
					end        
				else
					success = true
					successes += 1.0
					node.bufferAdd(key, item)
				end
			end

			# log information about successes and failures, where the item was
			# deposited, and the path it took. 
			stats[r] = {'source' => initiator, 
						'failures' => probe.getFailures, 
						'success' => success, 
						'path' => probe.to_s, 
						'put_location'=> node.nid
					}
		}

		return stats
	end

	def get(k)
		walk_length = randWalkLength()
		path = []
		initiator = @nid
		hash = computeHash(k + @@hash_functions[rand(@@hash_functions.length)].to_s)
		probe = Probe.new(initiator, hash, walk_length, path)
		last_node, probe = random_walk(probe)
		probe.pop_last() #prevents adding id to path twice
		found_minimum = last_node.deterministic_walk(probe)
		# note that 'item' will be null if this LM does not have the item. 
		item = found_minimum.retrieve(k)
		# return probe so can print stats about path. 
		return item, probe
	end

	def managedGet(k, max=100)
		# repeats the get request until it succeeds (or gets to 'max') and keeps
		# statistics on failures
		item_found = false
		tries = 0
		stats = {}
		until item_found or tries == max
			item_found, probe_data = get(k)
			cost = probe_data.getPath.length
			tries += 1
		end
		# recall = TP/(TP+FN). a 'FN' (false negative) is when get() falsely
		# returns nil. in this case the loop stops at TP=1 and thus tries is equal
		# to TP+FN. 
		if item_found
			recall = 1.0/(tries)
			stats["success"] = true
		else
			recall = 0
			stats["success"] = false
		end
		stats["tries"] = tries
		stats["max_tries"] = max
		return item_found, recall, stats
	end

	def computeHash(nid)
		d = Digest::SHA1.hexdigest(nid.to_s).hex
		return d.modulo(2**@@lambda)
	end

	def keyDistance(hash2)
		# computes distance between the current node, and the given key 
		w1 = (@hashID - hash2).modulo(2**@@lambda)
		w2 = (hash2 - @hashID).modulo(2**@@lambda)
		if w1 < w2
			return w1
		else
			return w2
		end
	end

	def neighborhood
		nbrs = getNeighbors()
		return nbrs if @@hops == 1 

		# keep track of which neighbours we've already calculated so we don't
		# duplicate efforts. 
		alreadyCalculated = []
		@@hops.times{
			moreNbrs = nbrs
			nbrs.each{|nbr|
				unless alreadyCalculated.include? nbr   
					moreNbrs += getPhysicalNbrs(nbr)
					alreadyCalculated.push(nbr) 
				end
			} 
			nbrs += moreNbrs
		}
		nbrs.delete(@nid)	
		return nbrs.uniq
	end

	def local_minimum(k)
		# returns the node in the h-hop neighborhood whose hash forms a local
		# minimum with the key to be stored
		min_node = self
		min_dist = keyDistance(k)
		neighbors = neighborhood()
		neighbors.each{|node|
			dist = node.keyDistance(k)
			if dist < min_dist
				min_dist = dist
				min_node = node
			end
		}
		return min_node
	end

	def receive_probe(probe)
		# note that this method adds the NEXT node (the node it has chosen) to
		# the probe path, not itself. ('itself' was added by the previous node)
		if probe.random_walk? 
			probe.decrease_steps
			randomNode = neighbors[rand(neighbors.length)]
			probe.path << randomNode
		else # deterministic walk
			min_node = local_minimum(probe.get_key)
			if min_node.nid == @nid
				status, reason = buffer_store(probe.item)
				if status == true
					probe.status = :success
				else
					probe.fail
					probe.status = :failure
					probe.error = reason
				end
			else
				probe.path << min_node.nid
			end
		end
		return probe
	end

#	def random_walk(probe)
#		neighbors = getNeighbors()
#		#puts "in random_walk, #{@nid}'s neighbors = #{neighbors}"
#		probe.walk()
#		probe.add_to_path(@nid)
#		if probe.getLength() > 0
#			if neighbors.length > 0
#				randomNode = neighbors[rand(neighbors.length)]
#				return randomNode.random_walk(probe)
#			else
#				probe.walk_length = 0
#				return self, probe
#			end
#		else
#			return self, probe
#		end
#	end

#	def deterministic_walk(probe)
#		probe.add_to_path(@nid)
#		# local minima for this item's key
#		min_node = local_minimum(probe.getKey())
#		if min_node.nid == @nid
#			return self
#		else
#			return min_node.deterministic_walk(probe)
#		end
#	end


end

class Probe
	def initialize(initiator, key, walk_length)
		@initiator = initiator
		@key = key
		@walk_length = walk_length
		@path = []
		@status = :outbound
		@error
	end
	attr_accessor :path, :walk_length, :status

	def random_walk?
		return @walk_length > 0 || false
	end

	def decrease_steps
		@walk_length -=1
	end

	def setLength(length)
		@walk_length = length
	end

	def getKey()
		return @key
	end

	def getInitiator()
		return @initiator
	end

	def finalNode()
		return @path.last
	end

	def to_s
		s = ""
		@path.each{|p|
			s += p.to_s + "->"
		}
		return s.chop.chop
	end

  def clearPath
    @path.clear()
  end  

  def pop_last()
    return @path.pop
  end
end

class PUTProbe < Probe
  def initialize(item, initiator, key, walk_length)
    super(initiator, key, walk_length)
    @item = item 
	@failure_count =  0
  end
  attr_reader :item
  
  def getFailures()
    return @failure_count
  end
  
  def fail()
    @failure_count += 1
  end
end


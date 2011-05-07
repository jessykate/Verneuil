=begin
	this module acts like a black box message for passing between the node
	and its environment. by implementing it as a module, it simply helps to
	make the code more modularized. we could define a different module with
	different behaviour for getting the neighbors.  

=end

module Comms
	# defines a simulated communications ability for the nodes.
	# needs to talk to the one simulator, and every node.
	# usage: in an experiment, once a simulator s is defined:
	# class Node
	#	extend Comms
	# end
	# # commSetup is a class method
	# Node.commSetup(s)
	# n = Node.new
	# n.getNeighbors()

	def self.setup(s)
		@@sim = s
	end
	attr_accessor :sim

	def self.sim
		return @@sim
	end

	def self.included(base)
		# we want all nodes to share access to the same simulator, so sim
		# is a true class variable. 
		base.send('class_variable_set', :@@sim, Comms.sim)
	end

	# instance method that Nodes will use to communicate with the outside
	# world (simulator). 
	def getNeighbors()
		@@sim.getPhysicalNbrs(@nid)
	end

end

class TopologyError < RuntimeError; end
class InvalidNodeID < RuntimeError; end

module UDSTopology 
	# defines behaviour specific to a uniform disc topology (2D euclidean
	# space with wrap-around behaviour). Is also demonstrative of the methods
	# that another topology module would need to define to function with the
	# Simulator. Pay attention to return values, they will be expected by the
	# simulator. 

	def uds_init(width, height)
		# initialization function
		@width = width
		@height = height
		puts "width = #{width}, height=#{height}"
		# keep track of which locations are occupied. 
		@occupied = Hash.new
		(0..@width-1).each{|x|
			(0..@height-1).each{|y|
				@occupied[[x,y]] = false
				print '.'
			}
		}
		puts ""
		$stdout.flush
	end

	def distance(n1, n2)
		# compute the euclidean distance between two node objects (noting that
		# an object at (0,0) and (0,width-1) are neighbours in a space with
		# wrap-around behaviour). 
		xDist = (n1.x - n2.x).abs % @width
		yDist = (n1.y - n2.y).abs % @height
		#puts "xDist = #{xDist}; yDist = #{yDist}"
		tot = Math.sqrt(xDist**2 + yDist**2)
		#puts "total distance = #{tot}"
		return tot
	end

	def moveNode(nodeID, newX, newY)
		# move nodeID to a specific location specified by a tuple (in this
		# case, (x,y), ensuring the location remains within the bounds of the
		# defined topology. 	
		oldX = @nodes[nodeID].x
		oldY = @nodes[nodeID].y
		raise TopologyError, "Location (#{newX}, #{newY}) out of bounds" if 
		!validLocation(newX, newY)
		raise TopologyError, "Cannot move node to occupied location" if 
		@occupied[[newX,newY]]
		@occupied[[oldX,oldY]] = false
		@nodes[nodeID].x = newX
		@nodes[nodeID].y = newY
		@occupied[[newX,newY]] = true
		#puts "Moved #{nodeID} to (#{newX}, #{newY})"
		return true
	end

	def validLocation(x,y)
		if x < 0 or x > @width or y < 0 or y > @height
			return false
		else
			return true
		end
	end

	def addNode()
		# pick randomly from the set of empty locations. alternatively, we
		# could pick a random spot until we find one that's unoccupied.  One
		# might argue that nodes should preferentially enter from the edges of
		# the space only.  however, there are various reasons why this might
		# not be the case-- getting out of a car, turning on a device, etc. 
		available = emptySpots()
		if available.empty?
			return false
		else
			loc = available[rand(available.length)]
			return addNodeAtLocation(*loc)
		end
	end

	def addNodeAtLocation(x,y)
		raise TopologyError, "Location (#{newX}, #{newY}) out of bounds" if 
		!validLocation(x,y)
		raise TopologyError, "Location out of bounds" if !validLocation(x,y)
		@occupied[[x,y]] = true
		n = @Node.new
		# singleton methods. hawt. 
		n.instance_eval {
			@x = x
			@y = y
			def x; return @x; end
			def y; return @y; end
			def x=(newX); @x=newX; end
			def y=(newY); @y=newY; end
		}
		@nodes[n.nid] = n
		return n
	end

	def removeNode(nodeID)
		# delete the node and update its location to un-occupied. return true
		# for success, false for failure
		n = @nodes[nodeID]
		unless n == nil 
			@occupied[[n.x,n.y]] = false
			@nodes.delete(nodeID)		
			return true
		end
		return false
	end

	def validOneStepLocations(nodeID)
		# returns valid locations (in absolute terms) that the node may move to
		# in one step, taking into account topology and removing any occupied
		# spots

		# here we allow a node to move to any of the 8 spots immediately
		# adjacent, including on the diagonal.
		valid = []
		x = @nodes[nodeID].x
		y = @nodes[nodeID].y
		[-1,0,1].each{|relX|
			absX = (x+relX) % @width
			[-1,0,1].each{|relY|
				absY = (y+relY) % @height	
				valid.push([absX, absY]) unless @occupied[[absX,absY]]
			}
		} 
		return valid
	end

	def emptySpots()
		# returns an array of [x,y] coords which are empty (unoccupied)
		empty = []
		# fancy-pants ruby block notation... <3.  
		@occupied.each{|loc, occupied| empty << loc if occupied == false}
		return empty
	end

	def clear
		# clears current nodes but does not reset time
		@nodes = {}
		@occupied = Hash.new
		(0..@width-1).each{|x|
			(0..@height-1).each{|y|
				@occupied[[x,y]] = false
			}
		}

	end

end


module LMSEvents
	# include in the simulator
	
	def print_replica_stats(s)
		s.sort.each{|replica,info|
			puts "replica #{replica}"
			puts "-------------------"
			info.each{|k,v|
				puts "#{k}: #{v}"
			}
			puts ""
		}
	end

	def put(nodeID, tag, message, replicas)
		puts "@time=#{@time} in #{__method__}"
		# gotta update neighbors before we start put-ing. 
		raise InvalidNodeID if nodeID >= @nodes.length
		queue(@time+1, :update_nbrs, nodeID)
		queue(@time+2, :put_init, nodeID, tag, message, replicas)
	end

	def get(nodeID, tag)
		puts "@time=#{@time} in #{__method__}"
		raise InvalidNodeID if nodeID >= @nodes.length
		# gotta update neighbors before we start get-ing. 
		queue(@time+1, :update_nbrs, nodeID)
		queue(@time+2, :get_init, nodeID, tag)
	end

	def put_init(nodeID, tag, message, replicas)
		puts "@time=#{@time} in #{__method__}"
		replicas.times {
			@stats[:lms_put_attempts] += 1
			probe = @nodes[nodeID].put_init(tag, message, replicas, @time)
			if probe == :isolated
				# then the probe failed because the node had no neighbors. gather
				# some stats and discontinue this probe. 
				@stats[:lms_put_failures_isolated] += 1
				@stats[:lms_put_giveup] += 1
				return
			end
			dst_node = probe.path.last
			puts "got dst_node = #{dst_node}"
			# all these events get queued at the same relative time since they
			# happen for different nodes
			queue(@time+1, :update_nbrs, dst_node)
			queue(@time+2, :send_probe, dst_node, probe)
		}
	end

	def get_init(nodeID, tag)
		puts "@time=#{@time} in #{__method__}"
		@stats[:lms_get_attempts] += 1
		probe = @nodes[nodeID].get_init(tag, @time)
		if probe == :isolated
			# then the probe failed because the node had no neighbors. gather
			# some stats and discontinue this probe. 
			@stats[:lms_get_failures_isolated] += 1
			@stats[:lms_get_giveup] += 1
			return
		end
		dst_node = probe.path.last
		puts "got dst_node = #{dst_node}"
		queue(@time+1, :update_nbrs, dst_node)
		queue(@time+2, :send_probe, dst_node, probe)
	end

	def update_nbrs(nodeID)
		# NOTE only suport 1-hop neighborhoods right now
		puts "@time=#{@time} in #{__method__}"
		# update the nbrs of nodeID
		puts "updating nbrs for node #{nodeID}"
		nbrs = get_physical_nbrs(nodeID)
		@stats[:avg_neighbors] = Float((@stats[:avg_neighbors]*@stats[:neighbor_updates]) + 
								nbrs.length)/Float(@stats[:neighbor_updates]+1)
		@stats[:neighbor_updates] += 1
		@nodes[nodeID].update_nbrs = nbrs

		# AFTER we update the nbr nodes, with some probability move/kill
		# other nodes.
		# ...
	end
	
	def send_probe(nodeID, probe_in)
		puts "@time=#{@time} in #{__method__}"
		probe_out = @nodes[nodeID].receive_probe(probe_in, @time)
		if probe_out == :isolated
			# then the probe failed because the node had no neighbors. gather
			# some stats and discontinue this probe. 
			if probe_in.type == :put
				@stats[:lms_put_failures_isolated] += 1
				@stats[:lms_put_giveup] += 1
			else
				@stats[:lms_get_failures_isolated] += 1
				@stats[:lms_get_giveup] += 1
			end
			return
		end
		dst_node = probe_out.path.last
		if dst_node == nodeID
			# dst_node WAS the local minima. reply to the initiating node with
			# the probe, containing success or failure information. (don't need
			# to update neighbors here since we're starting at the same node we
			# just came from) (probably, this decision should be made by the
			# NODE, not the simulator). 
			if probe_out.type == :put
				queue(@time+1, :put_probe_reply, nodeID, probe_out.initiator, msg = {:probe, probe_out, :hops, 0})  
			else
				queue(@time+1, :get_probe_reply, nodeID, probe_out.initiator, msg = {:probe, probe_out, :hops, 0})  
			end
		else
			# update the neighbors of the destination node, and then send
			queue(@time+1, :update_nbrs, dst_node) 
			queue(@time+2, :send_probe, dst_node, probe_out)
		end
	end

	def get_probe_reply nodeID, dst, msg 
		# find the way back to the original node
		response = @nodes[nodeID].forward_get_reply(dst, msg, @time)
		case response[:status]
		when :forward
			queue(@time+1, :update_nbrs, response[:data][:next_hop]) 
			queue(@time+2, :get_probe_reply, response[:data][:next_hop], 
				  response[:data][:dst], response[:data][:msg] )
		when :failure
			# record reason for failure.
			case response[:error]
			when :isolated
				@stats[:lms_get_failures_isolated] += 1
			when :missing
				@stats[:lms_get_failures_missing] += 1
			when :lost
				@stats[:lms_get_failures_lost] += 1
			end
			@stats[:lms_get_giveup] += 1
		when :success
			delta_t = response[:data][:probe].end_time - response[:data][:probe].start_time
			@stats[:avg_get_time] = Float(@stats[:lms_get_successes]*@stats[:avg_get_time]+ 
										  delta_t)/Float(@stats[:lms_get_successes]+1)
			@stats[:lms_get_successes] += 1
			delta_t_reply = @time - response[:data][:probe].end_time
			@stats[:avg_get_reply_time] = Float(@stats[:lms_get_successes]*@stats[:avg_get_reply_time]+ 
										  delta_t_reply)/Float(@stats[:lms_get_successes]+1)
			puts "item retrieved:"
			response[:data][:probe].item.each{|tag, location_list|
				puts "#{tag}: "
				pp location_list
			}
		else
			raise UnknownEventError
		end
		unless response[:status] == :forward or response[:error] == :lost 
			location_found= response[:data][:probe].path.last
			key_searched= response[:data][:probe].orig_key
			#puts location_found
			#puts key_searched
			#gets
			@stats[:get_locations][key_searched] << location_found
		end
	end

	def put_probe_reply nodeID, dst, msg 
		# find the way back to the original node
		response = @nodes[nodeID].forward_put_reply(dst, msg, @time)
		case response[:status]
		when :forward
			queue(@time+1, :update_nbrs, response[:data][:next_hop]) 
			queue(@time+2, :put_probe_reply, response[:data][:next_hop], 
				  response[:data][:dst], response[:data][:msg] )
		when :retry, :failure
			# record reason for failure in both cases. then retry if that's
			# what was specified. 
			case response[:error]
			when :isolated
				@stats[:lms_put_failures_isolated] += 1
			when :duplicate
				@stats[:lms_put_failures_duplicate] += 1
			when :full
				@stats[:lms_put_failures_full] += 1
			when :lost
				@stats[:lms_put_failures_lost] += 1
			end
			if response[:status] == :retry
				@stats[:lms_put_retries] += 1
				queue(@time+1, :update_nbrs, response[:data][:next_hop]) 
				queue(@time+2, :send_probe,response[:data][:next_hop],response[:data][:new_probe])
			else # status == failure
				@stats[:lms_put_giveup] += 1
			end
		when :success
			delta_t = response[:data][:probe].end_time - response[:data][:probe].start_time
			@stats[:avg_put_time] = Float(@stats[:lms_put_successes]*@stats[:avg_put_time]+ 
										  delta_t)/Float(@stats[:lms_put_successes]+1)
			@stats[:lms_put_successes] += 1
			delta_t_reply = @time - response[:data][:probe].end_time
			@stats[:avg_put_reply_time] = Float(@stats[:lms_put_successes]*@stats[:avg_put_reply_time]+ 
										  delta_t_reply)/Float(@stats[:lms_put_successes]+1)
			location_stored = response[:data][:probe].path.last
			key_stored = response[:data][:probe].orig_key
			@stats[:put_locations][key_stored] << location_stored
		else
			raise UnknownEventError
		end
	end

end



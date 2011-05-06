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
	
	def print_stats(s)
		s.sort.each{|replica,info|
			puts "replica #{replica}"
			puts "-------------------"
			info.each{|k,v|
				puts "#{k}: #{v}"
			}
			puts ""
		}
	end

	def put_init(nodeID, tag, message, replicas)
		probe = @nodes[nodeID].put_init(tag, message)
		queue(@time+1, :update_nbrs, nodeID, :send_probe, nodeID, probe)
	end

	def update_nbrs(nodeID, next_event, *args)
		# update the nbrs of nodeID, then call the next_event with *args

		nbrs = get_physical_nbrs(nodeID)
		@nodes[nodeID].update_nbrs = nbrs

		# AFTER we update the nbr nodes, with some probability move/kill
		# other nodes.
		# ...

		queue(@time+1, next_event, *args)
	end
	
	def send_probe(nodeID, probe_in)
		probe_out = @nodes[nodeID].receive_probe(probe_in)
		dst_node = probe_out.path.last
		if dst_node == nodeID
			# dst_node was the local minima. reply to the original node, with
			# the probe containing success or failure information. 
			queue(@time+1, :probe_reply, nodeID, probe_out.initiator, probe)  
		else
			# update the neighbors of the destination node, and then send
			queue(@time+1, :update_nbrs, dst_node, :send_probe, dst_node, probe_out)
		end
	end

	def probe_reply nodeID, dst, probe
		# do a deterministic walk back to the original node
		next_hop = @nodes[nodeID].forward_reply(dst, probe)
		if next_hop != nodeID
			queue(@time+1. :update_nbrs, next_hop, :probe_reply, dst, probe)
		end
	end


	def lms_put(nodeID, tag, message, replicas)
		stats = @nodes[nodeID].put(tag, message, replicas)
		print_stats(stats)
	end

	def lms_get(nodeID, tag)
		# returns item, probe
		return @nodes[nodeID].get(tag)
	end

	def lms_managed_get(nodeID, tag)
		return @nodes[nodeID].managedGet(tag)
	end
end



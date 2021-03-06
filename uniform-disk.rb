module UDSTopology 
	# topology-specific mixing for even simulator. 

	# defines behaviour specific to a uniform disc topology (2D euclidean
	# space with wrap-around behaviour). Is also demonstrative of the methods
	# that another topology module would need to define to function with the
	# Simulator. Pay attention to return values, they will be expected by the
	# simulator. 

	# custom error class topology-related errors
	class TopologyError < RuntimeError; end

	def uds_init(width, height)
		# initialization function
		@width = width
		@height = height
		puts "width = #{width}, height=#{height}"
		# keep track of which locations are occupied. 
		@occupied = Hash.new{|h,k| h[k] = false}

		#(0..@width-1).each{|x|
		#	(0..@height-1).each{|y|
		#		@occupied[[x,y]] = false
		#		print '.'
		#	}
		#}
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
		raise TopologyError, "Location (#{newX}, #{newY}) out of bounds" if !validLocation(newX, newY)
		raise TopologyError, "Cannot move node to occupied location" if @occupied[[newX,newY]]
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
		available = emptySpot()
		return addNodeAtLocation(*available) unless not available
		#available = emptySpots()
#		if available.empty?
#			puts "sim full!"
#			return false
#		else
#			loc = available[rand(available.length)]
#			return addNodeAtLocation(*loc)
#		end
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
			@dead_nodes << nodeID
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

	def emptySpot
	# makes use of the assumption that occupied locations will be sparse
		# compared to empty locations, and that making a list of all empty
		# locations is always O(area), whereas in general this will be O(1) or
		# O(2)
		if @occupied.length == @width*@height
			puts "sim full!"
			return false
		end
		while true
			x = rand(@width)
			y = rand(@height)
			if not @occupied[[x,y]]
				return [x,y]
			end
		end
	end

	def emptySpots()
		# returns an array of [x,y] coords which are empty (unoccupied)
		empty = []
		occ_locations = @occupied.keys
		(0..@width-1).each{|x|
			(0..@height-1).each{|y|
				# hopefully this is faster than visiting every location in the
				# occupied array. but assumes that in general occuied locations
				# will be sparse compared to total locations.
				empty << [x,y] if not occ_locations.include? [x,y]
				#@occupied.each{|loc, occupied| empty << loc if occupied == false}
			}
		}
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





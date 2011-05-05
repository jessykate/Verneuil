
class PriorityQueue
	def initialize
		@q = Hash.new {|hash, key| hash[key] = []}
	end

	def insert(priority, data)
		# lower priority is HIGHER
		@q[priority] << data
	end

	def next
		# events with the lowest (soonest) time are removed first. 
		next_events = @q.sort[0]
		@q.delete(ret[0]) #delete by key value
		return next_events
	end
end

class Simulator_old
	
	def initialize()
		@nodes = {} # nid : node
		@time = 0

		# there are some basic supported events for every simulator.
		# Additionally, protocol-specific behaviour can be defined in a module
		# and then included in a specific simulator. When that happens, the
		# protocol-specific event module implements both a method for their
		# event(s), and registers their event by adding it to the
		# supportedEvents hash. It is worth noting that certain NON-event
		# functionality is supported as well, such as retrieving a node, or
		# calculating neighbours, etc. Non-events are for inspection only, they
		# do not increase the time or change the state of the system
		@supportedEvents = {'addNode' => :addNode,
							'addNodes' => :addNodes, 
							'addNode' => :addNode, 
							'addNodeAtLocation' => :addNodeAtLocation, 
							'removeNode' => :removeNode,
							'removeNodes' => :removeNodes,
							'advanceState' => :advanceState,
							'moveNodes' => :moveNodes,
							'stepNodeRandom' =>  :stepNodeRandom,
						} # {eventName => :functionReference, ...}

		# keep a priority queue for system events. general format for each
		# item:
		# { priority => {eventName => 'event', eventArgs => 'argList'}}
		@Q = PriorityQueue.new

	end	
	attr_accessor :time

	def num_nodes
		return @nodes.length
	end

	def getPhysicalNbrs(nodeID)
		# iterate over all nodes and if the distance is within the broadcast
		# radius of the node, then it is a physical neighbour. O(n). Returns a
		# list of node objects. 
		thisNode = @nodes[nodeID]
		nbrs = []
		@nodes.values.each{|otherNode|
			if ((thisNode != otherNode) and 
				distance(thisNode, otherNode) < thisNode.broadcastRadius)
				nbrs.push(otherNode)
			end
		}
		return nbrs
	end 

	def event(eventName, *eventArgs)
		# everything we ask the sim to do can get passed through this method,
		# which will log the actions, increase the time step, and do other
		# management tasks as needed. 
			
		@time += 1
		send(@supportedEvents[eventName], *eventArgs) if 
			@supportedEvents.include? eventName 

		# do some fancy logging here?
	end

	def queue(time, eventName, *eventArgs)
		# @Q is a priority queue. events get popped off in priority order. 
		@Q.insert(priority = time, data = [eventName, eventArgs])
	end

	def run(condition=true)
		# condition must evaluate to a boolean
		while condition
			time, events_now = @Q.next
			until events_now.is_empty?
			   eventName, eventArgs = events_now.shift	
			   event(eventName, *eventArgs)
		end

	############## all methods that follow are private ############
	###############################################################
	private 

	def getNode(nodeID)
		return @nodes[nodeID]
	end

	def stepNodeRandom(nodeID)
		# modes the node one step in a random direction. return true unless
		# there are no open neighbouring positions, in which case returns
		# false. 
		valid = validOneStepLocations(nodeID)
		if valid.empty?
			return false
		else
			new = valid[rand(valid.length)]
			moveNode(nodeID, new[0], new[1])
		end
		return true
	end

	def addNodes(num)
		num.times{
			# adds the node to the topology
			n = addNode()
		}
	end

	def removeNodes(num)
		# delete one or more nodes selected at random
		num.times {
			nid = @nodes.keys()[rand(@nodes.length)]
			removeNode(nid)	
		}
	end

	def moveNodes(num)
		alreadyMoved = []
		while num > 0 do
			nid = @nodes.keys()[rand(@nodes.length)]
			unless alreadyMoved.include? nid
				stepNodeRandom(nid) 
				num -= 1
			end
		end
	end


	def advanceState(numNew, numKill, percentMove)
		# advances the state of the system by one slice of time. the
		# system state consists of current nodes' positions, new nodes being
		# added, and existing nodes being killed off. 
		
		# note: if a node is going to be killed there's no point moving it. if
		# a node is going to be added there's also no point moving it (since
		# its initial location is random anyway). main design decision is
		# whether to add new nodes/kill off old nodes before or after the
		# existing nodes move. since the movement is random, i believe these
		# are equivalent-- that is, it doesn't matter. 

		removeNodes(numKill) unless numKill == 0
		addNodes(numNew) unless numNew == 0
		numMove = (@nodes.length * percentMove).round 
		moveNodes(numMove) unless numMove == 0
	end
		

end


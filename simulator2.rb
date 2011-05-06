require 'node'
require 'lms'


class NonLinearTimeError < RuntimeError; end

class PriorityQueue
	def initialize
		@q = Hash.new {|hash, key| hash[key] = []}
		def @q.to_s 
			s = ""
			self.each{|k,v|
				s += "#{k}: #{v} "
			}
			return s
		end
	end

	def insert(priority, data)
		# lower priority is HIGHER
		@q[priority] << data
	end

	def next
		# events with the lowest (soonest) time are removed first. 
		return [false,false] if @q.empty?
		next_events = @q.sort[0]
		@q.delete(next_events[0]) #delete by key value
		# returns false if @q is empty. 
		return next_events 
	end

	def to_s
		return "#{@q.length} items: { #{@q.to_s} }"
	end
end

class Simulator
	
	def initialize()
		@nodes = {} # nid => node
		@time = 0
		# keep a priority queue for system events. general format for each
		# item:
		@stats = {
			:avg_put_time, 0, :avg_get_time, 0, :avg_nbrs, 0, 
			:lms_put_failures, 0, :lms_put_attempts, 0, 
			:lms_get_failures, 0, :lms_get_attempts, 0,
			:messages_expected, 0, :messages_present, 0,
		}
		@Q = PriorityQueue.new

	end	
	attr_accessor :time, :Q

	def node_type node_class, *mixins
		mixins.each{|mixin|
			node_class.class_eval {
				include mixin
			}
		}
		@Node = node_class
	end

	def num_nodes
		return @nodes.length
	end

	def queue(time, eventName, *eventArgs)
		# @Q is a priority queue. events get popped off in priority order. 
		puts "queueing #{eventName}"
		@Q.insert(priority = time, data = [eventName, eventArgs])
	end

	def run(condition=true)
		# condition must evaluate to a boolean
		while condition
			time, events_now = @Q.next
			break if events_now == false
			raise NonLinearTimeError if time < @time
			# update the time
			@time = time
			# process the events scheduled for this time. events_now is a list
			# of events, size >= 1.
			until events_now.empty?
				eventName, eventArgs = events_now.shift	
				# eventName is a symbol or string
				puts "time #{time}: event #{eventName} with args #{eventArgs}"
				send(eventName, *eventArgs)
			end
		end
		puts "finished!"
	end

	#############################################################
	#	aggregate events (most of which in turn call basic events)
	#############################################################

	def addNodes(num)
		num.times{
			# adds the node to the topology
			n = addNode()
			puts "\tnode placed at #{n.x}, #{n.y}"
		}
	end

	def moveNodes(num)
		# randomly selects num nodes and moves them one step. The nodes are
		# independent, so all movements happen in parallel in one time unit. 
		alreadyMoved = []
		while num > 0 do
			nid = @nodes.keys()[rand(@nodes.length)]
			unless alreadyMoved.include? nid
				stepNodeRandom(nid) 
				num -= 1
			end
		end
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

	#	basic events
	def get_physical_nbrs(nodeID)
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


	#	convenience methods

end


	

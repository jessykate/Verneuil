require 'node'
require 'lms'


class NonLinearTimeError < RuntimeError; end
class UnknownEventError < RuntimeError; end

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
			:avg_put_time, 0, :avg_get_time, 0, 
			:avg_put_reply_time, 0, :avg_get_reply_time, 0, 
			:avg_neighbors,0, :neighbor_updates, 0,
		   	:avg_density, 0, :density_updates, 0,

			:lms_put_attempts, 0, 
			:lms_put_successes, 0, 
			:lms_put_retries, 0,
			:lms_put_giveup, 0,
			# includes failure data for retries as well. 
			:lms_put_failures_isolated, 0,
			:lms_put_failures_full, 0,
			:lms_put_failures_duplicate, 0,
			:lms_put_failures_lost, 0,

			:lms_get_attempts, 0,
			:lms_get_successes, 0, 
			:lms_get_giveup, 0,
			:lms_get_failures_isolated, 0,
			:lms_get_failures_missing, 0,
			:lms_get_failures_lost, 0,
			

			:put_locations, Hash.new {|hash, key| hash[key] = []},
			:get_locations, Hash.new {|hash, key| hash[key] = []},
			:messages_expected, 0, :messages_present, 0,
		}
		@Q = PriorityQueue.new

	end	
	attr_reader :time, :Q, :stats

	def print_stats
		puts "\t\t\tAverages"
		puts "============================================================="
		
		puts "avg_put_time\t\t\t#{@stats[:avg_put_time]}"
		puts "avg_put_reply_time\t\t#{@stats[:avg_put_reply_time]}"
		puts "avg_get_time\t\t\t#{@stats[:avg_get_time]}"
		puts "avg_get_reply_time\t\t#{@stats[:avg_get_reply_time]}"
		puts "avg_neighbors\t\t\t#{@stats[:avg_neighbors]}"
		puts "neighbor updates\t\t#{@stats[:neighbor_updates]}"
		puts "avg_density\t\t\t#{@stats[:avg_density]}"
		puts "density_updates\t\t\t#{@stats[:density_updates]}"

		puts "\n\t\t\tPut Statistics"
		puts "============================================================="

		puts "lms_put_attempts\t\t#{@stats[:lms_put_attempts]}"
		puts "lms_put_successes\t\t#{@stats[:lms_put_successes]}"
		puts "lms_put_retries\t\t\t#{@stats[:lms_put_retries]}"
		puts "lms_put_giveup\t\t\t#{@stats[:lms_put_giveup]}"
		puts "lms_put_failures_isolated\t#{@stats[:lms_put_failures_isolated]}"
		puts "lms_put_failures_full\t\t#{@stats[:lms_put_failures_full]}"
		puts "lms_put_failures_duplicate\t#{@stats[:lms_put_failures_duplicate]}"
		puts "lms_put_failures_lost\t\t#{@stats[:lms_put_failures_lost]}"

		puts "\n\t\t\tGet Statistics"
		puts "============================================================="

		puts "lms_get_attempts\t\t#{@stats[:lms_get_attempts]}"
		puts "lms_get_successes\t\t#{@stats[:lms_get_successes]}"
		puts "lms_get_giveup\t\t\t#{@stats[:lms_get_giveup]}"
		puts "lms_get_failures_isolated\t#{@stats[:lms_get_failures_isolated]}"
		puts "lms_get_failures_missing\t#{@stats[:lms_get_failures_missing]}"
		puts "lms_get_failures_lost\t\t#{@stats[:lms_get_failures_lost]}"

		puts "\n\t\t\tRequest Details"
		puts "============================================================="

		puts "put_locations"
		@stats[:put_locations].each{|tag, location_list|
			puts "for tag #{tag}: "
			location_list.uniq.sort.each{|x|
				print "#{x},"
			}
			puts ""
		}
		
		puts ""
		puts "get_locations"
		@stats[:get_locations].each{|tag, location_list|
			puts "for tag #{tag}: "
			location_list.uniq.sort.each{|x|
				print "#{x},"
			}
			puts ""
		}

		puts ""
		@stats[:put_locations].each{|tag, location_list|
			puts "comparison for tag #{tag}"
			(location_list - @stats[:get_locations][tag]).sort.each{|x|
				print "#{x},"
			}
			puts ""
			
		}

	end

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
		puts "queueing #{eventName} for time #{time}"
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

	def addNodes(num)
		num.times{
			# adds the node to the topology
			n = addNode()
		}
		current_density = Float(@nodes.length)/Float(@width*@height)
		@stats[:avg_density] = Float((@stats[:avg_density]*@stats[:density_updates]) + 
								current_density)/Float(@stats[:density_updates]+1)
		@stats[:density_updates] += 1
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

	def removeNodes(num)
		# delete one or more nodes selected at random
		num.times {
			nid = @nodes.keys()[rand(@nodes.length)]
			removeNode(nid)	
		}
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
		# list of node IDs. 
		thisNode = @nodes[nodeID]
		nbrs = []
		@nodes.values.each{|otherNode|
			if ((thisNode != otherNode) and 
				distance(thisNode, otherNode) < thisNode.broadcastRadius)
				nbrs.push(otherNode.nid)
			end
		}
		return nbrs
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

	#	convenience methods

end


	

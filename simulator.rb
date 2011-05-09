require 'node'
require 'lms'


class NonLinearTimeError < RuntimeError; end
class UnknownEventError < RuntimeError; end
class InvalidNodeID < RuntimeError; end
class InvalidProbability < RuntimeError; end
class InvalidDistance < RuntimeError; end
class DeadNodeError < RuntimeError; end

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

	def insert(priority, event_id, data)
		# lower priority is HIGHER

		# neat way to generate a short uniq id (uses base 36), from
		# http://blog.logeek.fr/2009/7/2/creating-small-unique-tokens-in-ruby
		event_id = rand(36**8).to_s(36) unless event_id
		# each event contains event_name, event_args, event_id
		@q[priority] << data + [event_id]
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
		@nodes = Hash.new {|hash, key| node_moved_or_died(key) if @dead_nodes.include? key } # nid => node
		@dead_nodes = []
		@time = 0
		@current_event_id = nil

		# keep a priority queue for system events. general format for each
		# item: priority => [eventName, eventArgs]
		@Q = PriorityQueue.new

		# probability of nodes moving, joining, and parting the network at any
		# given timestep. 
		@move = 0.0
		@part = 0.0
		@join = 0.0

		# fun, fun statistics. 
		@stats = {
			:events_per_unit_time, [],

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
			
			# a record of locations where items were stored and attempts were
			# made to retrieve. 
			:put_locations, Hash.new {|hash, key| hash[key] = []},
			:get_locations, Hash.new {|hash, key| hash[key] = []},
			
			# for each message, log {event_id => {start_time, end_time, history}
			# history is one of success, dropped, lost, full, duplicate
			:message_log, {},
			
			:messages_expected, 0, :messages_present, 0,
		}

	end	
	attr_reader :time, :Q, :stats

	def print_stats

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

		puts "\t\t\tEvents per unit time"
		puts "============================================================="
		pp @stats[:events_per_unit_time].sort{|a,b| a[:time]<=>b[:time]}
		
		puts ""

#		puts "\t\t\tEvent Histories"
#		puts "============================================================="
#		# the sort block sorts by the first timestamp in the event history
#		@stats[:message_log].sort{|a,b| a[1][0][0]<=>b[1][0][0] }.each{|event_id, history|
#			puts event_id
#			history.each{|time, event|
#				print "t#{time}: #{event}. "
#			}
#			puts ""
#		}

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
		puts "Total messages\t\t\t#{@stats[:message_log].length}"

		puts "\n\t\t\tPut Statistics"
		puts "============================================================="
		
		put_logs = @stats[:message_log].reject{|k,v| v[0][1] != :put}
		puts "Total Put Messages = #{put_logs.length}"

		num_dropped = put_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :dropped}}
		puts "num_dropped = #{num_dropped}"

		num_success = put_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :success}}
		puts "num_success= #{num_success}"

		num_isolated= put_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :isolated}}
		puts "num_isolated= #{num_isolated}"

		num_lost = put_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :lost}}
		puts "num_lost= #{num_lost}"
		
		num_full= put_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :full}}
		puts "num_full= #{num_full}"
		
		num_duplicate= put_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :duplicate}}
		puts "num_duplicate= #{num_duplicate}"
		
		num_retry= put_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :retry}}
		puts "num_retry= #{num_retry}"

		puts "\n\t\t\tGet Statistics"
		puts "============================================================="
		
		get_logs = @stats[:message_log].reject{|k,v| v[0][1] != :get}
		puts "Total Get Messages = #{get_logs.length}"

		num_dropped = get_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :dropped}}
		puts "num_dropped = #{num_dropped}"

		num_success = get_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :success}}
		puts "num_success= #{num_success}"

		num_isolated= get_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :isolated}}
		puts "num_isolated= #{num_isolated}"

		num_lost = get_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :lost}}
		puts "num_lost= #{num_lost}"
		
		num_full= get_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :full}}
		puts "num_full= #{num_full}"
		
		num_duplicate= get_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :duplicate}}
		puts "num_duplicate= #{num_duplicate}"
		
		num_retry= get_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :retry}}
		puts "num_retry= #{num_retry}"

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

	def queue(time, event_id, event_name, *event_args)
		# queues the event with args. @Q is a priority queue. events get popped
		# off in priority order. 
		puts "queueing #{event_name} for time #{time}"
		@Q.insert(priority = time, event_id, data = [event_name, event_args])
	end

	def run(condition=true)
		# condition must evaluate to a boolean
		while condition
			time, events_now = @Q.next
			break if events_now == false
			raise NonLinearTimeError if time < @time

			@stats[:events_per_unit_time] << {:time, @time, :num_events, events_now.length}
			# update the time
			@delta_t = time - @time
			@time = time
			
			# each time step, independent of what has been scheduled, we update
			# node positions and network membership according to the values set
			# up in the dynamics() method. 

			# how many to operate on? (need to get this number before we change
			# number of nodes)
			starting_size = @nodes.length
			#room_available = (@width*@height)-starting size

			puts "network size this step: #{starting_size}"
			puts "delta_t: #{@delta_t}"

			# (note: there's a difference between moving each of n nodes t
			# steps, and n nodes one step at each t. the latter will result in
			# some overlap, so seems slightly more 'correct')
			num_move = Integer(@move*starting_size) 
			distance = @delta_t
			# former approach: moveNodes(num_move, distance)
			# latter approach:
			distance.times { moveNodes(num_move) } unless num_move == 0

			# how many to add?
			# note: add them after the move
			num_join= Integer(@join*starting_size*@delta_t)
			puts "adding #{num_join}"

			# how many to kill off?
			# note: calling this before or after adding nodes will affect
			# whether we only kill off nodes that were present durin the last
			# event or also some which could have showed up after. in general,
			# the latter seems more accurate. (although a bit of a waste
			# computationally). 
			num_part = Integer(@part*starting_size*@delta_t)
			puts "removing #{num_part}"

			# this is some trickery so that, if there's a big jump in time,
			# adding or removing all the nodes first doesn't completelly kill
			# the network. 
			common = (num_part < num_join ? num_part : num_join )
			(2*common).times {|i|
				(i % 2) == 0 ? addNodes(1) : removeNodes(1)
			} unless (num_part == 0 or num_join == 0)

			unless num_join == num_part
				num_join > num_part ? remaining = :addNodes : remaining = :removeNodes
				send(remaining,  (num_join-num_part).abs)
			end
			puts "number of dead nodes = #{@dead_nodes.length}."
			#pp @dead_nodes
			puts "number of live nodes = #{@nodes.length}."
			#pp @nodes.keys

			# process the events scheduled for this time. events_now is a list
			# of events, size >= 1.
			until events_now.empty?
				
				event_name, event_args, event_id = events_now.shift	
				puts "time #{time}: event #{event_name} with args #{event_args}"
	
				@current_event_id = event_id

				# start/append to the history for this event
				if not @stats[:message_log][event_id]
					@stats[:message_log][event_id] = []
				end

				@stats[:message_log][event_id] << [@time, event_name]

				# if any event attempts to act on a dead node, or send a
				# message to a node which is no longer accessible from the
				# originator, message_dropped gets thrown (and
				# node_moved_or_died gets called). 
				catch :message_dropped do 
					send(event_name, *event_args) 
				end
			end
		end
		puts "finished!"
	end

	def node_moved_or_died nodeID
		# update statistics and drop the message
		@stats[:message_log][@current_event_id] << [@time, :dropped]
		puts "message dropped. punting"
		throw :message_dropped
	end

	def gaussian_rand 
		# returns a value between 0 and 1 from a gaussian distribution. see
		# http://www.taygeta.com/random/gaussian.html. 
		begin
			u1 = 2 * rand - 1
			u2 = 2 * rand - 1
			w = u1 * u1 + u2 * u2
		end while w >= 1

		w = Math::sqrt( ( -2 * Math::log(w)) / w )
		g2 = u1 * w;
		g1 = u2 * w;
		return g1
	end				

	def dynamics move, join, part
		# move, join and part represent probability values for each action.
		# these probabilities are applied to a random subset of nodes before
		# each event, to simulate regular dynamics. so if move = 0.2, and the
		# delta time between the last event and this event is 10 time units,
		# then 20% of nodes could have moved up to 10 steps during that time.
		# the amount they actually move is a random number between 0 and
		# delta_t, sampled from a gaussian distribution. updates can be
		# scheduled during simulation execution, or set once and applied for
		# the duration.  
		raise InvalidProbability if move < 0 or move > 1
		raise InvalidProbability if join < 0 or join > 1
		raise InvalidProbability if part < 0 or part > 1
		@move = move
		@join = join
		@part = part
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
		puts "updated neighbors for node #{nodeID} with list #{nbrs}"
	end
	
	def verify_neighbors(origin, destination)
		node_moved_or_died destination unless 
		get_physical_nbrs(origin).include? destination or 
		origin == destination
	end

	def addNodes(num)
		print "adding nodes with ids "
		num.times{
			# add the node to the topology
			n = addNode()
			print "#{n.nid} " if n
		}
		current_density = Float(@nodes.length)/Float(@width*@height)
		@stats[:avg_density] = Float((@stats[:avg_density]*@stats[:density_updates]) + 
								current_density)/Float(@stats[:density_updates]+1)
		@stats[:density_updates] += 1
		puts ""
	end

	def moveNodes(num, distance=1)
		# randomly selects num nodes and moves them distance (default 1). The nodes are
		# independent, so all movements happen in parallel in one time unit. 
		raise InvalidDistance if not distance.is_a? Integer
		alreadyMoved = []
		while num > 0 do
			nid = @nodes.keys()[rand(@nodes.length)]
			unless alreadyMoved.include? nid
				alreadyMoved << nid
				distance.times {
					stepNodeRandom(nid) 
				}
				num -= 1
			end
		end
	end

	def removeNodes(num)
		# delete one or more nodes selected at random
		print "removing nodes "
		num.times {
			nid = @nodes.keys()[rand(@nodes.length)]
			print "#{nid} "
			removeNode(nid)	
		}
		puts ""
		current_density = Float(@nodes.length)/Float(@width*@height)
		@stats[:avg_density] = Float((@stats[:avg_density]*@stats[:density_updates]) + 
								current_density)/Float(@stats[:density_updates]+1)
		@stats[:density_updates] += 1
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

end


	

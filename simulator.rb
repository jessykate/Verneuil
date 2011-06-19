require 'node'
require 'pp'

class NonLinearTimeError < RuntimeError; end
class UnknownEventError < RuntimeError; end
class InvalidNodeID < RuntimeError; end
class InvalidProbability < RuntimeError; end
class InvalidDistance < RuntimeError; end
class DeadNodeError < RuntimeError; end

class Simulator
	
	def self.new_event_id
		# neat way to generate a short uniq id (uses base 36), from
		# http://blog.logeek.fr/2009/7/2/creating-small-unique-tokens-in-ruby
		rand(36**8).to_s(36) 
	end

	class PriorityQueue
		def initialize
			# the queue is a set of key-value pairs where the key is the time
			# (priority) and the value is a list of events to be executed at
			# that time. 
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
			event_id = Simulator.new_event_id unless event_id
			# each event contains event_name, event_args, event_id
			@q[priority] << data + [event_id]
		end

		def find_event event_id=nil, event_name=nil, arg=nil
			# searches through the queue using event_id or event name, and then
			# narrows down the selection using the arguments criteria (ie arg
			# is some value that should be one of the arguments). 
			matches = @q 
			puts "the queue contains the following contents:"
			pp @q
			# each 'value' is a list of lists. we want to check the list within each list
			if event_id
				next_matches = {}
				matches.each{|k,events_this_priority|
					events_this_priority.each{|set_of_events|
						if set_of_events.last == event_id
							next_matches[k] = next_matches.fetch(k,[]) << set_of_events
						end
					}
				}
				matches = next_matches
				puts "matches against event_id #{event_id}"
				pp matches
			end
			if event_name
				next_matches = {}
				matches.each{|k,events_this_priority|
					events_this_priority.each{|set_of_events|
						if set_of_events.first == event_name
							next_matches[k] = next_matches.fetch(k,[]) << set_of_events
						end
					}
				}
				matches = next_matches
				puts "matches against event_name #{event_name}"
				pp matches
			end
			# values are each a list of event_name, event_args, event_id
			if arg
				next_matches = {}
				matches.each{|k,events_this_priority|
					events_this_priority.each{|set_of_events|
						if set_of_events[1].include? arg
							next_matches[k] = next_matches.fetch(k,[]) << set_of_events
						end
					}
				}
				matches = next_matches
				puts "matches against arg #{arg}"
				pp matches
			end
			return matches
		end

		def deschedule priority, event_data
			@q[priority].delete(event_data)
			if @q[priority].empty?
				@q.delete priority
			end
		end

		def next
			# events with the lowest (soonest) time are removed first. 
			# returns false if @q is empty. 
			return [false,false] if @q.empty?
			next_events = @q.sort[0]
			@q.delete(next_events[0]) #delete by key value
			return next_events 
		end

		def future_event_names
			# data always contains method name first
			x = @q.values.collect{|data| data.collect{|event_info| event_info[0]}}
			return x
		end

		def to_s
			return "#{@q.length} items: { #{@q.to_s} }"
		end
	end

	def initialize()
		@dead_nodes = []
		@nodes = Hash.new {|hash, key| node_moved_or_died(key) if @dead_nodes.include? key } # nid => node
		@time = 0
		@current_event_id = nil
		@title = "Simulation"

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

			:avg_neighbors,0, :neighbor_updates, 0,
		   	:avg_density, 0, :density_updates, 0,
			:avg_nbr_percent_change, 0,

			# TODO these should be in lmsevents
			:lms_put_attempts, 0, 
			:lms_put_successes, 0, 
			:avg_put_time, 0, :avg_get_time, 0, 
			:avg_put_reply_time, 0, :avg_get_reply_time, 0, 
			:lms_get_attempts, 0,
			:lms_get_successes, 0, 
			
			# a record of locations where items were stored and attempts were
			# made to retrieve, respectively
			:put_locations, Hash.new {|hash, key| hash[key] = []},
			:get_locations, Hash.new {|hash, key| hash[key] = []},
			
			# events are comprised of many secondary events which get queued.
			# events are related by an event_id which is passed along with it
			# through its history. that history is logged here, keyed on
			# event_id. each event_id points to a list of (time, event) tuples
			# that describe the life of that activity in the simulator.  
			# {event_id => [[time_i, event], ...,[time_n, event]]}
			:message_log, {},
		}

	end	
	attr_reader :time, :Q, :stats

	def node_type node_class, *mixins
		# specify a generic node class with one or more mixins, which implement
		# the protocol(s) to be tested. 
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

	def queue_periodic event_name, delta_t
		# a method to call every delta_t time units
		@periodic_events = @periodic_events || []
		@periodic_events << [event_name, delta_t]
	end


	def run(title="Just another simulation", condition=false)
		# the user can specify some custom termination condition (must evaluate
		# to a boolean), else simulator will run until all the event have been
		# exhausted. 
		@title = title
		# time offset is used in the offchance that the first event is not
		# scheduled for time 0
		time_offset = 0
		first_event = true
		#unless condition == true
		while true

			time, events_now = @Q.next

			if first_event			
				time_offset = time 
				first_event = false
			end

			break if events_now == false
			raise NonLinearTimeError if time < @time

			# update the time
			@delta_t = time - @time
			@time = time
			@stats[:events_per_unit_time] << {:time, @time, :num_events, events_now.length}

			# check for and schedule any periodic events as necessary. 
			if @periodic_events 
				# check for a break condition - the periodic events only get
				# scheduled if there are other 'real' events that still have to
				# get executed. 
				periodic_event_types = @periodic_events.collect{|item| item[0]}
				real_events = @Q.future_event_names.uniq - periodic_event_types
				puts "real events remaining"
				pp real_events
				unless real_events.empty?
					@periodic_events.each {|event, interval|
						if (@time-time_offset) % interval == 0
							puts "queueing periodic event #{event} for time #{@time+time_offset+interval}"
							queue(time = @time+time_offset+interval, event_id = nil, event, nil) 
						end
					}
				end
			end

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
			puts "number of live nodes = #{@nodes.length}."

			# process the events scheduled for this time. events_now is a list
			# of events, size >= 1 (there are typically multiple events at the
			# same time). 
			until events_now.empty?
				
				event_name, event_args, event_id = events_now.shift	
				pp "time #{time}: event #{event_name} with args #{event_args}"
	
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
					puts event_args
					if event_args == [nil]
						send(event_name)
					else
						send(event_name, *event_args) 
					end
				end
			end
			puts @Q
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
		g2 = u1 * w
		g1 = u2 * w
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
		# update the nbrs of nodeID
		# NOTE only suports 1-hop neighborhoods right now
		puts "@time=#{@time} in #{__method__}"
		puts "updating nbrs for node #{nodeID}"
		nbrs = get_physical_nbrs(nodeID)

		# store the average number of neighbours 
		@stats[:avg_neighbors] = Float((@stats[:avg_neighbors]*@stats[:neighbor_updates]) + 
								nbrs.length)/Float(@stats[:neighbor_updates]+1)

		# store the percent neighbour change
		new = (@nodes[nodeID].neighbors - nbrs)
		percent_change = Float(new.length)/Float(@nodes[nodeID].neighbors.length)
		@stats[:avg_nbr_percent_change] = Float((@stats[:avg_nbr_percent_change]*@stats[:neighbor_updates]) + 
								percent_change)/Float(@stats[:neighbor_updates]+1)
		
		# NOW update the count of neighbour updates
		@stats[:neighbor_updates] += 1

		# finally update the neighbor list
		@nodes[nodeID].update_nbrs = nbrs
		puts "updated neighbors for node #{nodeID} with list #{nbrs}"
	end
	
	def verify_neighbors(origin, destination)
		nbrs = get_physical_nbrs origin
		puts "origin: #{origin}. destination: #{destination}. nrbs of origin:"
		puts nbrs
		puts "actual stored neighbours:"
		puts @nodes[origin].neighbors
		puts "last event"
		puts @stats[:message_log][@current_event_id][-1]
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


	

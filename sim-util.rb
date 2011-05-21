#!/usr/bin/ruby

require 'lmsevents'
require 'uniform-disk'
require 'simulator'
require 'pp'
require 'date'

class Simulator
	include UDSTopology 
	include LMSEvents
end

# this method represents a simple run of the the simulator, with a series of
# put requests followed by a series of get reqests. 
def simple_run title, width, height, move, join, part, initial_nodes, 
	num_puts, num_gets, wait_time

	sim = Simulator.new
	sim.run title
	sim.uds_init width, height
	sim.node_type Node, LMS

	sim.queue(time=0, event_id=nil, :dynamics, move, join, part)
	sim.queue(time=1, event_id=nil, :addNodes, initial_nodes)

	# queue a bunch of events at a time slightly after sim initialization
	num_puts.times {|n|
		sim.queue(time=10+n, event_id=nil, :put, tag = "tests", msg = "hello 2 #{n}", replicas=5)
	}

	start_gets = 10+num_puts+wait_time

	num_gets.times {|n|
		sim.queue(time=start_gets+n, event_id=nil, :get, tag = "tests")
	}

	sim.run title
	sim.print_stats
	# stats is the generic simulator stats
	stats = sim.stats
	# stats_get is stats specifically about get requests
	stats[:get_data] = sim.stats_get
	# stats_put is stats specifically about put requests
	stats[:put_data] = sim.stats_put
	return stats
end


def simple_experiment_set description, params, control, control_values

	# set up the log file and make a header with all the input parameters
	log = File.new("logs/experiment#{DateTime.now.strftime("%Y-%h-%dT%H-%M-%S")}.csv", "w")
	log.puts "Experiment Description: #{description}"
	params.each{|k,v|
		log.puts "# #{k}: #{v}"
	}
	log.puts "# ----------------------------------\n"
	log.puts "run, #{control}, put_messages, put_dropped, put_success, put_isolated, put_lost, put_full, put_duplicate, put_retry, get_messages, get_dropped, get_success, get_isolated, get_lost, get_missing, put_avg, put_reply_avg, get_avg, get_reply_avg, avg_nbrs, nbr_updates, avg_density, total_msgs\n"

	run = 0

	control_values.each {|v|
		LMS.setup hops = 	params[:hops] || v, 
			lambda_	=		params[:lambda_] || v, 
			max_failures =	params[:max_failures] || v, 
			randWalkRange =	params[:randWalkRange] || v, 
			randWalkMin =	params[:randWalkMin] || v, 
			reply_ttl =		params[:reply_ttl] || v
		
		Node.setup broadcastRange = params[:broadcastRange] || v, 
			broadcastMin =	params[:broadcastMin] || v, 
			bufferRange =	params[:bufferRange] || v, 
			bufferMin =		params[:bufferMin] || v

		stats = simple_run title = description, 
			width =			params[:width] || v, 
			height =		params[:height] || v, 
			move =			params[:move] || v,
			join =			params[:join] || v,
			part =			params[:part] || v,
			initial_nodes = params[:initial_nodes] || v, 
			num_puts =		params[:num_puts] || v, 
			num_gets =		params[:num_gets] || v, 
			wait_time =		params[:wait_time] || v

		get_data = stats[:get_data]
		put_data = stats[:put_data]
		# log the relevant stats for each run. 
		log.puts "#{run}, #{v}, #{put_data[:num_messages]}, #{put_data[:num_dropped]}, #{put_data[:num_success]}, #{put_data[:num_isolated]}, #{put_data[:num_lost]}, #{put_data[:num_full]}, #{put_data[:num_duplicate]}, #{put_data[:num_retry]}, #{get_data[:num_messages]}, #{get_data[:num_dropped]}, #{get_data[:num_success]}, #{get_data[:num_isolated]}, #{get_data[:num_lost]}, #{get_data[:num_missing]}, #{stats[:avg_put_time]}, #{stats[:avg_put_reply_time]}, #{stats[:avg_get_time]}, #{stats[:avg_get_reply_time]}, #{stats[:avg_neighbors]}, #{stats[:neighbor_updates]}, #{stats[:avg_density]}, #{stats[:message_log].length}\n"

		run +=1
	}
	log.close
end

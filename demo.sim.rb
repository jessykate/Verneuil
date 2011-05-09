#!/usr/bin/ruby
require 'mixins'
require 'simulator'
require 'pp'

class Simulator
	include UDSTopology 
	include LMSEvents
end

# TOY =========================================

LMS.setup hops=1, lambda_=256, max_failures=5, randWalkRange=10, randWalkMin=10, reply_ttl=1000
Node.setup broadcastRange=2, broadcastMin=10, bufferRange=3, bufferMin=5

movement_probabilities = [0.95, 0.85]#0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.1, 0.2, 0.3, 0.5, 0.6, 0.7, 0.8, 0.9] 
movement_probabilities.each {|p|
	sim = Simulator.new
	sim.uds_init width = 10, height = 10
	sim.node_type Node, LMS

	sim.queue(time=0, event_id=nil, :dynamics, move=p, join=0.0, part=0.0)
	sim.queue(time=1, event_id=nil, :addNodes, 50)

	10.times {|n| 
		sim.queue(time=2, event_id=nil, :put, tag = "tests", msg = "hello #{n}", replicas=5)
	}
	100.times {|n|
		sim.queue(time=115+n, event_id=nil, :get, tag = "tests")
	}

	#sim.queue(0, event_id=nil, acts_on=nil, :dynamics, move=0.2, join=0.2, part=0.1)

	sim.run
	sim.print_stats
}

exit

# SIM =========================================

LMS.setup hops=1, lambda_=256, max_failures=5, randWalkRange=10, randWalkMin=5, reply_ttl=1000
Node.setup broadcastRange=50, broadcastMin=100, bufferRange=10, bufferMin=50

movement_probabilities = [0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.1, 0.2, 0.3, 0.5, 0.6, 0.7, 0.8, 0.9] 
movement_probabilities.each {|p|

	sim = Simulator.new
	sim.uds_init width = 100, height = 100
	sim.node_type Node, LMS

	sim.queue(time=0, event_id=nil, :dynamics, move=p, join=0.0, part=0.0)
	sim.queue(time=1, event_id=nil, :addNodes, 200)

	### percentage of nbrs changing and correlation with/probability of failure. TODO

	10.times {|t|
		20.times {|n| 
			sim.queue(time=2+n+t, event_id=nil, :put, tag = "tests", msg = "hello 2 #{t}.#{n}", replicas=5)
		}
	}

	# issue 200 GET queries, 50 at a time, over 40 time periods 
	10.times {|t|
		20.times {|n|
			sim.queue(time=100+t+n, event_id=nil, :get, tag = "tests")
		
		}
	}

	sim.run
	sim.print_stats
}



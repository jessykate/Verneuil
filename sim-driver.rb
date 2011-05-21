#!/usr/bin/ruby
require 'lmsevents'
require 'uniform-disk'
require 'simulator'
require 'pp'

class Simulator
	include UDSTopology 
	include LMSEvents
end

# SIM =========================================
# movement probability, no join or part

LMS.setup hops=1, lambda_=256, max_failures=5, randWalkRange=50, randWalkMin=5, reply_ttl=1000
Node.setup broadcastRange=5, broadcastMin=5, bufferRange=10, bufferMin=50

#[0.01, 0.02, 0.03, 0.04, 0.05, 0.06]

movement_probabilities = [0.0,]# 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0] 
movement_probabilities.each {|p|

	sim = Simulator.new
	sim.uds_init width = 100, height = 10
	sim.node_type Node, LMS

	sim.queue(time=0, event_id=nil, :dynamics, move=p, join=0.0, part=0.0)
	sim.queue(time=1, event_id=nil, :addNodes, 500)

	10.times {|t|
		20.times {|n| 
			sim.queue(time=2+n+t, event_id=nil, :put, tag = "tests", msg = "hello 2 #{t}.#{n}", replicas=5)
		}
	}

	# issue 200 GET queries, 20 at a time, over 10 time periods 
	10.times {|t|
		20.times {|n|
			sim.queue(time=10+t+n, event_id=nil, :get, tag = "tests")
		
		}
	}

	# should store delta time between put and retrieval...
	sim.run title="small broadcast radius"
	sim.print_stats
}

exit 

# SIM =========================================
# increase join/part probability

LMS.setup hops=1, lambda_=256, max_failures=5, randWalkRange=10, randWalkMin=5, reply_ttl=1000
Node.setup broadcastRange=2, broadcastMin=3, bufferRange=10, bufferMin=50

part_probs = [0.01, 0.02, 0.03, 0.04, 0.05]
part_probs.each{|p|
	sim = Simulator.new
	sim.uds_init width = 100, height = 100
	sim.node_type Node, LMS

	sim.queue(time=0, event_id=nil, :dynamics, move=0.5, join=p, part=p)
	sim.queue(time=1, event_id=nil, :addNodes, 200)

	10.times {|t|
		20.times {|n| 
			sim.queue(time=2+n+t, event_id=nil, :put, tag = "tests", msg = "hello 2 #{t}.#{n}", replicas=5)
		}
	}

	10.times {|t|
		20.times {|n|
			sim.queue(time=1000+t+n, event_id=nil, :get, tag = "tests")
		
		}
	}

	# should store delta time between put and retrieval...
	sim.run title="network density scaling"
	sim.print_stats
}

exit

# SIM =========================================
# scale the network density

LMS.setup hops=1, lambda_=256, max_failures=5, randWalkRange=10, randWalkMin=5, reply_ttl=1000
Node.setup broadcastRange=5, broadcastMin=10, bufferRange=10, bufferMin=50

#[0.01, 0.02, 0.03, 0.04, 0.05, 0.06]

num_nodes = [10, 50, 100, 200, 300, 400, 500, 700, 900]
num_nodes.each{|n|
	sim = Simulator.new
	sim.uds_init width = 100, height = 10
	sim.node_type Node, LMS

	sim.queue(time=0, event_id=nil, :dynamics, move=0.5, join=0.0, part=0.0)
	sim.queue(time=1, event_id=nil, :addNodes, n)

	### percentage of nbrs changing and correlation with/probability of failure. TODO

	10.times {|t|
		20.times {|n| 
			sim.queue(time=2+n+t, event_id=nil, :put, tag = "tests", msg = "hello 2 #{t}.#{n}", replicas=5)
		}
	}

	# issue 200 GET queries, 20 at a time, over 10 time periods 
	10.times {|t|
		20.times {|n|
			sim.queue(time=1000+t+n, event_id=nil, :get, tag = "tests")
		
		}
	}

	# should store delta time between put and retrieval...
	sim.run title="network density scaling"
	sim.print_stats
}

exit 

# TOY =========================================

# want something where broadcast radius is around the avg. distance between nodes. 

LMS.setup hops=1, lambda_=256, max_failures=5, randWalkRange=10, randWalkMin=10, reply_ttl=1000
Node.setup broadcastRange=2, broadcastMin=10, bufferRange=3, bufferMin=5

movement_probabilities = [0.95, 0.85,0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.1, 0.2, 0.3, 0.5, 0.6, 0.7, 0.8, 0.9] 
movement_probabilities.each {|p|
	sim = Simulator.new
	sim.uds_init width = 100, height = 100
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


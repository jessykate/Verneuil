#!/usr/bin/ruby
require 'mixins'
require 'simulator'
require 'pp'

class Simulator
	include UDSTopology 
	include LMSEvents
end

LMS.setup hops=1, lambda_=256, max_failures=5, randWalkRange=10, randWalkMin=5, reply_ttl=1000
Node.setup broadcastRange=50, broadcastMin=100, bufferRange=10, bufferMin=20

sim = Simulator.new
sim.uds_init width = 50, height = 50
sim.node_type Node, LMS

sim.queue(time=0, event_id=nil, :dynamics, move=0.01, join=0.01, part=0.01)

sim.queue(time=1, event_id=nil, :addNodes, 75)

sim.queue(time=2, event_id=nil, :put, tag = "tests", msg = "hello 1", replicas=5)
sim.queue(time=2, event_id=nil, :put, tag = "tests", msg = "hello 2", replicas=5)
sim.queue(time=2, event_id=nil, :put, tag = "tests", msg = "hello 3", replicas=5)
sim.queue(time=3, event_id=nil, :put, tag = "tests", msg = "hello 4", replicas=5)
sim.queue(time=4, event_id=nil, :put, tag = "tests", msg = "hello 5", replicas=5)

sim.queue(time=5, event_id=nil, :put, tag = "cat", msg = "cat 1", replicas=5)
sim.queue(time=6, event_id=nil, :put, tag = "cat", msg = "cat 2", replicas=5)
sim.queue(time=7, event_id=nil, :put, tag = "cat", msg = "cat 3", replicas=5)
sim.queue(time=8, event_id=nil, :put, tag = "cat", msg = "cat 4", replicas=5)
sim.queue(time=9, event_id=nil, :put, tag = "cat", msg = "cat 5", replicas=5)

100.times {|n|
	sim.queue(time=10+n, event_id=nil, :get, tag = "tests")
}

#sim.queue(0, event_id=nil, acts_on=nil, :dynamics, move=0.2, join=0.2, part=0.1)

100.times {|n|
	sim.queue(time=115+n, event_id=nil, :get, tag = "cat")
}

sim.run
sim.print_stats

exit

# split up put
# make some nodes move, die probabilistically when a put is issued. 
# make get nbrs, random walk events queue-able

# logging
# stats

#!/usr/bin/ruby
require 'mixins'
require 'simulator'
require 'pp'

class Simulator
	include UDSTopology 
	include LMSEvents
end
sim = Simulator.new
sim.uds_init width = 100, height = 100

Comms.setup(sim)
LMS.setup hops=1, lambda_=256, max_failures=5, randWalkRange=10, randWalkMin=5, reply_ttl=1000
Node.setup broadcastRange=50, broadcastMin=100, bufferRange=10, bufferMin=20
sim.node_type Node, LMS, Comms # do we need Comms anymore?

sim.dynamics(move=0.2, join=0.2, part=0.1)
sim.queue(0, :addNodes, 100)
sim.queue(1, :moveNodes, 3)

sim.queue(time=2, :put, 1, tag = "tests", msg = "hello 1", replicas=5)
sim.queue(time=2, :put, 9, tag = "tests", msg = "hello 2", replicas=5)
sim.queue(time=2, :put, 9, tag = "tests", msg = "hello 3", replicas=5)
sim.queue(time=3, :put, 9, tag = "tests", msg = "hello 4", replicas=5)
sim.queue(time=4, :put, 18, tag = "tests", msg = "hello 5", replicas=5)

sim.queue(time=200, :put, 1, tag = "cat", msg = "cat 1", replicas=5)
sim.queue(time=200, :put, 3, tag = "cat", msg = "cat 2", replicas=5)
sim.queue(time=200, :put, 4, tag = "cat", msg = "cat 3", replicas=5)
sim.queue(time=200, :put, 5, tag = "cat", msg = "cat 4", replicas=5)
sim.queue(time=200, :put, 6, tag = "cat", msg = "cat 5", replicas=5)

100.times {|n|
	sim.queue(time=700+n, :get, 10, tag = "tests")
}

100.times {|n|
	sim.queue(time=300+n, :get, 10, tag = "tests")
}

sim.run
sim.print_stats

exit

# split up put
# make some nodes move, die probabilistically when a put is issued. 
# make get nbrs, random walk events queue-able

# logging
# stats

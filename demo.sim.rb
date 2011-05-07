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
Node.setup broadcastRange=1, broadcastMin=5, bufferRange=10, bufferMin=20
sim.node_type Node, LMS, Comms # do we need Comms anymore?

sim.queue(0, :addNodes, 500)
sim.queue(1, :moveNodes, 30)
sim.queue(2, :put, 1, tag = "tests", msg = "hellow 1", replicas=5)
sim.queue(time=2, :put, 9, tag = "tests", msg = "hello 2", replicas=5)
sim.queue(time=2, :put, 9, tag = "tests", msg = "hello 3", replicas=5)
sim.queue(time=3, :put, 9, tag = "tests", msg = "hello 4", replicas=5)
sim.queue(time=4, :put, 20, tag = "tests", msg = "hello 5", replicas=5)
puts sim.Q
sim.run
sim.print_stats

exit

# split up put
# make some nodes move, die probabilistically when a put is issued. 
# make get nbrs, random walk events queue-able

# logging
# stats

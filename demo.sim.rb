#!/usr/bin/ruby
require 'mixins'
require 'simulator2'

class Simulator
	include UDSTopology 
	include LMSEvents
end
sim = Simulator.new
sim.uds_init width = 100, height = 100

Comms.setup(sim)
LMS.setup hops=1, lambda_=256, max_failures=5, randWalkRange=10, randWalkMin=5
Node.setup broadcastRange=1, broadcastMin=5, bufferRange=10, bufferMin=20
sim.node_type Node, LMS, Comms # do we need Comms anymore?

sim.queue(0, :addNodes, 500)
sim.queue(1, :moveNodes, 30)
sim.queue(2, :put, 1, tag = "tests", msg = "test message", replicas=5)
puts sim.Q
sim.run

exit

# split up put
# make some nodes move, die probabilistically when a put is issued. 
# make get nbrs, random walk events queue-able

# logging
# stats

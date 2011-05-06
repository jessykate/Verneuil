#!/usr/bin/ruby
require 'mixins'
require 'simulator2'

class Simulator
	include UDSTopology 
	include LMSEvents
end
sim = Simulator.new
sim.uds_init width = 10, height = 10

Comms.setup(sim)
LMS.setup hops=1, lambda_=256, max_failures=5, randWalkRange=10, randWalkMin=5
Node.setup broadcastRange=1, broadcastMin=5, bufferRange=10, bufferMin=20
sim.node_type Node, LMS, Comms # do we need Comms anymore?

sim.queue(0, :addNodes, 10)
sim.queue(1, :moveNodes, 3)
sim.queue(2, :lms_put, 1, msg = "test message", tag = "tests", replicas=5)
puts sim.Q
sim.run

exit

# split up put
# make some nodes move, die probabilistically when a put is issued. 
# make get nbrs, random walk events queue-able

# logging
# stats

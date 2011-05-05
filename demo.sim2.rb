#!/usr/bin/ruby
require 'mixins'
require 'simulator2'

class Simulator
	include UDSTopology 
end
sim = Simulator.new
sim.uds_init width = 10, height = 10

LMS.setup hops=1, lambda_=256, max_failures=5, randWalkRange=10, randWalkMin=5
Node.setup broadcastRange=1, broadcastMin=10, bufferRange=10, bufferMin=20
sim.node_type Node, LMS #Comms  do we need Comms anymore?

sim.queue(0, :addNodes, 10)
sim.queue(1, :moveNodes, 3)
puts sim.Q
sim.run

exit
sim.queue(2, :lmsput, msg = "test message", tag = "tests")


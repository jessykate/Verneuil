#!/usr/bin/ruby

require 'pdrevents'
require 'pdr'
require 'uniform-disk'
require 'simulator'
require 'pp'
require 'date'

class Simulator
	include UDSTopology 
	include PDREvents
end

PDR.setup beacon_interval=5, delay_factor=10, timeout=10, credits=0
Node.setup broadcastRange = 0, broadcastMin = 5, bufferRange = 0, bufferMin =	100

sim = Simulator.new
sim.uds_init width=10, height=10
sim.node_type Node, PDR

# will send out a beacon with subscription info at regular intervals
sim.queue_periodic :beacon, 5
sim.queue time=0, event_id=nil, :dynamics, move=0.5, join=0.0, part=0.0
sim.queue time=1, event_id=nil, :addNodes, initial_nodes=50
sim.queue time=10, event_id = nil, :add_subscription, 10, :activities
sim.queue time=11, event_id=nil, :publish_rand, 'chinese dragon festival', :activities
sim.queue time=12, event_id=nil, :publish_rand, 'chinese dragon festival', :activities
sim.queue time=13, event_id=nil, :publish_rand, 'chinese dragon festival', :activities

sim.run title = "demo"
sim.stats_put

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

PDR.setup beacon_interval=5, delay_factor=20, timeout=10, credits=0
Node.setup broadcastRange = 100, broadcastMin = 100, bufferRange = 0, bufferMin =	100

sim = Simulator.new
sim.uds_init width=1000, height=1000
sim.node_type Node, PDR

# will send out a beacon with subscription info at regular intervals
sim.queue_periodic :beacon, 5
sim.queue time=0, event_id=nil, :dynamics, move=0.4, join=0.0, part=0.0
sim.queue time=1, event_id=nil, :addNodes, initial_nodes=200
sim.queue time=11, event_id = nil, :add_subscription, 10, :activities

(26..40).each{|t| 
	if t % 2 == 0
		sim.queue time=t, event_id=nil, :publish_rand, 'pop-up art installation', :activities
	end
}

(25..39).each{|t| 
	if t % 2 == 1
		sim.queue time=t, event_id=nil, :publish_rand, 'chinese dragon festival', :activities
	end
}

sim.run title = "demo"
sim.stats_put

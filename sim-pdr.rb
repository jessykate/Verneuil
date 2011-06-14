#!/usr/bin/ruby

require 'lmsevents'
require 'uniform-disk'
require 'simulator'
require 'pp'
require 'date'

class Simulator
	include UDSTopology 
	include PDREvents
end

PDR.setup beacon_interval=5, delay_factor=10, timeout=10, credits=0

sim = Simulator.new
sim.uds_init width, height
sim.node_type Node, PDR

# will send out a beacon with subscription info at regular intervals
sim.queue_periodic beacon
sim.queue time=10, event_id = nil, :add_subscription, 10, 'events'
sim.queue time=11, event_id=nil, :publish_rand, 'chinese dragon festival', :events
sim.queue time=11, event_id=nil, :publish_rand, 'chinese dragon festival', :events


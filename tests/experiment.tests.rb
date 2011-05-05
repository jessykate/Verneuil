
$LOAD_PATH << '../'

require 'test/unit'
require '../mixins.rb'
require '../lms.rb'
require '../node.rb'

# Set up the classes for tests (this seems like a ghetto way to do this, but
# trying to mixin modules inside the test class throws errors)
LMS.setup(hops=1, lambda_=256, max_failures=5, randWalkRange=10, randWalkMin=5)
Node.setup(broadcastRange=1, broadcastMin=10, bufferRange=10, bufferMin=20)
$sim = Simulator.new
$sim.extend LMSEvents
UDSTopology.setup(width=100, height=100)
$sim.extend UDSTopology
Comms.setup($sim)
class Node
	include Comms
	include LMS
end

class SimulatorTests < Test::Unit::TestCase
end

class SimulatorTests
	def setup
		@sim = $sim 
		@sim.clear
	end

	def test_clear
		@sim.event('addNodes', 5)
		@sim.event('addNodes', 7)
		assert_equal(@sim.num_nodes, 12)
		@sim.clear
		assert_equal(@sim.num_nodes, 0)
	end

	def test_time
		start_time = @sim.time
		@sim.event('addNodes', 1)
		end_time = @sim.time
		assert(end_time == start_time + 1)
	end

	def test_node_comms_include
		n = Node.new
		assert(n.class.class_variables.include?("@@sim"))
		s = n.class.class_eval("@@sim")
		assert_kind_of(Simulator,s)
	end

	def test_distance
		# add two nodes at explicit locations and check that their distance is
		# what we expect it to be. 
		n1 = @sim.addNodeAtLocation(10,10)
		n2 = @sim.addNodeAtLocation(19,10)
		assert_equal(@sim.distance(n1,n2), 9)
	end

	def test_node_neighbors
		# add two nodes at explicit locations and check that their neighbor
		# relationship is as expected based on the broadcast radius, hops, etc. 

		# n1 and n2 should be neighbors
		n1 = @sim.event('addNodeAtLocation', 10,10)
		n2 = @sim.event('addNodeAtLocation', 10,15)
		
		# no neighbors
		n3 = @sim.event('addNodeAtLocation', 10,30)
		
		nbrs3 = n3.getNeighbors
		assert_equal(nbrs3, [])
		nbrs1 = n1.getNeighbors
		nbrs2 = n2.getNeighbors
		assert_equal(nbrs1, [n2])
		assert_equal(nbrs2, [n1])
	end

	def test_node_movement
		# check to see that a single step movement is within the radius
		# expected.
		n1 = @sim.event('addNodeAtLocation', 10,10)
		@sim.event('stepNodeRandom', n1.nid)
		puts "new position = (#{n1.x}, #{n1.y})"
		delX = (n1.x-10).abs 
		delY = (n1.y-10).abs 
		assert((delX == 1 or delX == 0))
		assert((delY == 1 or delY == 0))
	end

	def test_location_occupied
		# check to see that a movement to an occupied location will fail. 
		assert(@sim.num_nodes == 0)
		n1 = @sim.event('addNodeAtLocation', 10,10)
		assert_raise (TopologyError) {
			@sim.event('addNodeAtLocation', 10,10)
		}

		# check to make sure that node will not be moved if all neighboring
		# locations are occupied
		@sim.event('addNodeAtLocation', 9,9)
		@sim.event('addNodeAtLocation', 9,10)
		@sim.event('addNodeAtLocation', 9,11)
		@sim.event('addNodeAtLocation', 10,11)
		@sim.event('addNodeAtLocation', 11,11)
		@sim.event('addNodeAtLocation', 11,10)
		@sim.event('addNodeAtLocation', 11,9)
		@sim.event('addNodeAtLocation', 10,9)
		assert(@sim.event('stepNodeRandom', n1.nid) == false)
		
	end

	def test_add_nodes
		n = @sim.event('addNodes', 10)
		assert_equal(@sim.num_nodes, 10)
		assert_nothing_raised(TopologyError) {
			@sim.instance_eval {
				@nodes.each{|nid, n|
					if ((n.x < 0 or n.x > @width) or 
						(n.y < 0 or n.y > @height))
						raise TopologyError
					end
				}
			}
		}
		end

	def test_remove_node
		n = @sim.event('addNodeAtLocation', 9,9)
		assert_equal(@sim.num_nodes, 1)
		@sim.event('removeNode', n.nid)
		occupied = @sim.instance_variable_get(:@occupied)
		assert(occupied[[9,9]] == false)
		assert_equal(@sim.num_nodes, 0)
	end

	def test_advance_state
		@sim.event('addNodes', 100)
		# numNew, numKill, percentMove
		@sim.event('advanceState', 10,0,0)
		assert(@sim.num_nodes == 110)
		@sim.event('advanceState', 0,10,0)
		assert(@sim.num_nodes == 100)
		@sim.event('advanceState', 0,0,0.5)
		assert(@sim.num_nodes == 100)
	end

	def test_lms_put
		@sim.queue(time=1, 'addNodes', 100)
		# numNew, numKill, percentMove
		@sim.event('advanceState', 10,0,0)
		# nodeID, tag, msg, replicas
		@sim.event('LMSPut', 1, 'kittens', "kittens spotted at 5th and rhode island", 5)
		# nodeID, tag
		item, nil, stats = @sim.event('LMSManagedGet', 50, 'kittens')
		puts stats
	end

	def test_lms_get
		nil
	end



end

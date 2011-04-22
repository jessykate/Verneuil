# tests of node behaviour with LMS installed

$LOAD_PATH << '../'

require 'test/unit'
require '../mixins.rb'
require '../lms.rb'
require '../node.rb'

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

class NodeWithLMSTests < Test::Unit::TestCase

	def test_inst_var
		n = Node.new
		assert_not_nil(n.hashID)
	end

	def test_lms_node_class_vars
		observed = Node.class_variables
		expected = ["@@id", "@@broadcastMin", "@@broadcastRange", "@@hops","@@max_failures","@@randomWalkRange", "@@randomWalkMin", "@@lambda", "@@hash_functions"]
		assert_equal([], expected-observed)
	end



end	


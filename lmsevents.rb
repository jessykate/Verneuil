
module LMSEvents
	# LMS-specific events mixin. Include in simulator. 
	
	def print_replica_stats(s)
		s.sort.each{|replica,info|
			puts "replica #{replica}"
			puts "-------------------"
			info.each{|k,v|
				puts "#{k}: #{v}"
			}
			puts ""
		}
	end

	def put(tag, message, replicas)
		puts "@time=#{@time} in #{__method__}"
		# gotta update neighbors before we start put-ing. 
		nodeID = @nodes.keys()[rand(@nodes.length)]
		raise InvalidNodeID unless @nodes.keys.include?nodeID
		queue(@time+1, @current_event_id, :update_nbrs, nodeID)
		queue(@time+2, @current_event_id, :put_init, nodeID, tag, message, replicas)
	end

	def get(tag)
		puts "@time=#{@time} in #{__method__}"
		nodeID = @nodes.keys[rand(@nodes.length)]
		raise InvalidNodeID unless @nodes.keys.include?nodeID
		# gotta update neighbors before we start get-ing. 
		queue(@time+1, @current_event_id, :update_nbrs, nodeID)
		queue(@time+2, @current_event_id, :get_init, nodeID, tag)
	end

	def put_init(nodeID, tag, message, replicas)
		puts "@time=#{@time} in #{__method__}"
		replicas.times {
			@stats[:lms_put_attempts] += 1
			probe = @nodes[nodeID].put_init(tag, message, @time)
			if probe == :isolated
				# then the probe failed because the node had no neighbors. gather
				# some stats and discontinue this probe. 
				@stats[:message_log][@current_event_id] << [@time, :isolated]
			else
				dst_node = probe.path.last
				puts "got dst_node = #{dst_node}"
				# all these events get queued at the same relative time since they
				# happen for different nodes
				queue(@time+1, @current_event_id, :update_nbrs, dst_node)
				queue(@time+2, @current_event_id, :send_probe, nodeID, dst_node, probe)
			end
		}
	end

	def get_init(nodeID, tag)
		puts "@time=#{@time} in #{__method__}"
		@stats[:lms_get_attempts] += 1
		probe = @nodes[nodeID].get_init(tag, @time)
		if probe == :isolated
			# then the probe failed because the node had no neighbors. gather
			# some stats and discontinue this probe. 
			@stats[:message_log][@current_event_id] << [@time, :isolated]
		else
			dst_node = probe.path.last
			puts "got dst_node = #{dst_node}"
			queue(@time+1, @current_event_id, :update_nbrs, dst_node)
			queue(@time+2, @current_event_id, :send_probe, nodeID, dst_node, probe)
		end
	end

	def send_probe(origin, nodeID, probe_in)
		puts "@time=#{@time} in #{__method__}"

		# nodeID was chosen from a list of the origin's neighbors at the time
		# the message was scheduled. but it's possible the destination has
		# moved or died since then. if nodeID is no longer a nbr of origin,
		# then this message is dropped.
		verify_neighbors(origin, nodeID)

		probe_out = @nodes[nodeID].receive_probe(probe_in, @time)
		if probe_out == :isolated
			# then the probe failed because the node had no neighbors
			@stats[:message_log][@current_event_id] << [@time, :isolated]
			return
		end
		dst_node = probe_out.path.last
		if dst_node == nodeID
			# dst_node WAS the local minima. reply to the initiating node with
			# the probe, containing success or failure information. (don't need
			# to update neighbors here since we're starting at the same node we
			# just came from) (probably, this decision should be made by the
			# NODE, not the simulator). 
			if probe_out.type == :put
				queue(@time+1, @current_event_id, :put_probe_reply, nodeID, 
					probe_out.initiator, msg = {:probe, probe_out, :hops, 0})  
			else
				queue(@time+1, @current_event_id, :get_probe_reply, nodeID, 
					probe_out.initiator, msg = {:probe, probe_out, :hops, 0})  
			end
		else
			# update the neighbors of the destination node, and then send
			queue(@time+1, @current_event_id, :update_nbrs, dst_node) 
			queue(@time+2, @current_event_id, :send_probe, nodeID, dst_node, probe_out)
		end
	end

	def get_probe_reply nodeID, dst, msg 
		# find the way back to the original node

		verify_neighbors(nodeID, dst)
		
		response = @nodes[nodeID].forward_get_reply(dst, msg, @time)
		case response[:status]
		when :forward
			next_hop = response[:data][:next_hop]
			queue(@time+1, @current_event_id, :update_nbrs, next_hop) 
			queue(@time+2, @current_event_id, :get_probe_reply, next_hop, 
				  response[:data][:dst], response[:data][:msg] )
		when :failure
			@stats[:message_log][@current_event_id] << [@time, response[:error]]
		when :success
			@stats[:message_log][@current_event_id] << [@time, :success]
			delta_t = response[:data][:probe].end_time - response[:data][:probe].start_time
			@stats[:avg_get_time] = Float(@stats[:lms_get_successes]*@stats[:avg_get_time]+ 
										  delta_t)/Float(@stats[:lms_get_successes]+1)
			delta_t_reply = @time - response[:data][:probe].end_time
			@stats[:avg_get_reply_time] = Float(@stats[:lms_get_successes]*@stats[:avg_get_reply_time]+ 
										  delta_t_reply)/Float(@stats[:lms_get_successes]+1)
			puts "item retrieved:"
			response[:data][:probe].item.each{|tag, location_list|
				puts "#{tag}: "
				pp location_list
			}
		else
			raise UnknownEventError
		end
		unless response[:status] == :forward or response[:error] == :lost 
			location_found= response[:data][:probe].path.last
			key_searched= response[:data][:probe].orig_key
			#puts location_found
			#puts key_searched
			#gets
			@stats[:get_locations][key_searched] << location_found
		end
	end

	def put_probe_reply nodeID, dst, msg 
		# find the way back to the original node

		verify_neighbors(nodeID, dst)
		
		response = @nodes[nodeID].forward_put_reply(dst, msg, @time)
		case response[:status]
		when :forward
			next_hop = response[:data][:next_hop]
			queue(@time+1, @current_event_id, :update_nbrs, next_hop) 
			queue(@time+2, @current_event_id, :put_probe_reply, next_hop, 
				  response[:data][:dst], response[:data][:msg] )
		when :failure
			# record reason for failure in both cases. then retry if that's
			# what was specified. 
			@stats[:message_log][@current_event_id] << [@time, response[:error]]
		when :retry 
			next_hop = response[:data][:next_hop]
			queue(@time+1, @current_event_id, :update_nbrs, next_hop) 
			@stats[:message_log][@current_event_id] << [@time, :retry]
			queue(@time+2, @current_event_id, :send_probe, nodeID, next_hop, response[:data][:new_probe])
		when :success
			@stats[:message_log][@current_event_id] << [@time, :success]
			delta_t = response[:data][:probe].end_time - response[:data][:probe].start_time
			@stats[:avg_put_time] = Float(@stats[:lms_put_successes]*@stats[:avg_put_time]+ 
										  delta_t)/Float(@stats[:lms_put_successes]+1)
			delta_t_reply = @time - response[:data][:probe].end_time
			@stats[:avg_put_reply_time] = Float(@stats[:lms_put_successes]*@stats[:avg_put_reply_time]+ 
										  delta_t_reply)/Float(@stats[:lms_put_successes]+1)
			location_stored = response[:data][:probe].path.last
			key_stored = response[:data][:probe].orig_key
			@stats[:put_locations][key_stored] << location_stored
		else
			raise UnknownEventError
		end
	end

end


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
			@current_event_id = Simulator.new_event_id
			# this needs to go before the call to @nodes[nodeID] in case the
			# node has already died/moved. 
			# this is SO completelly the wrong place to put this. 
			@stats[:message_log][@current_event_id] = [[@time, :put_init],]
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
				# happen at different nodes. EACH put request should have a
				# distinct ID for tracking purposes. 
				event_id = Simulator.new_event_id
				queue(@time+1, @current_event_id, :update_nbrs, dst_node)
				queue(@time+2, @current_event_id, :send_probe, nodeID, dst_node, probe)
			end
		}
	end

	def get_init(nodeID, tag)
		puts "@time=#{@time} in #{__method__}"
		@current_event_id = Simulator.new_event_id
		# this needs to go before the call to @nodes[nodeID] in case the
		# node has already died/moved. 
		# this is SO completelly the wrong place to put this. 
		@stats[:message_log][@current_event_id] = [[@time, :get_init],]
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

		response = @nodes[nodeID].forward_get_reply(dst, msg, @time)
		case response[:status]
		when :forward
			next_hop = response[:data][:next_hop]
			verify_neighbors(nodeID, next_hop)
			queue(@time+1, @current_event_id, :update_nbrs, next_hop) 
			queue(@time+2, @current_event_id, :get_probe_reply, next_hop, 
				  response[:data][:dst], response[:data][:msg] )
			puts "event #{@current_event_id} in GET forward mode. current time: #{@time}"
		when :failure
			@stats[:message_log][@current_event_id] << [@time, response[:error]]
		when :success
			@stats[:message_log][@current_event_id] << [@time, :success]
			delta_t = response[:data][:probe].end_time - response[:data][:probe].start_time
			@stats[:avg_get_time] = Float(@stats[:lms_get_successes]*@stats[:avg_get_time]+ 
										  delta_t)/Float(@stats[:lms_get_successes]+1)
			delta_t_reply = @time - response[:data][:probe].end_time
			@stats[:message_log][@current_event_id] << [@time, "reply time = #{delta_t_reply}"]
			@stats[:avg_get_reply_time] = (Float(@stats[:lms_get_successes])*Float(@stats[:avg_get_reply_time])+ 
										  delta_t_reply)/Float(@stats[:lms_get_successes]+1)
			@stats[:lms_get_successes] += 1 
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
			@stats[:get_locations][key_searched] << location_found
		end
	end

	def put_probe_reply nodeID, dst, msg 
		# find the way back to the original node
		
		response = @nodes[nodeID].forward_put_reply(dst, msg, @time)
		case response[:status]
		when :forward
			next_hop = response[:data][:next_hop]
			verify_neighbors(nodeID, next_hop)
			queue(@time+1, @current_event_id, :update_nbrs, next_hop) 
			queue(@time+2, @current_event_id, :put_probe_reply, next_hop, 
				  response[:data][:dst], response[:data][:msg] )
			puts "event #{@current_event_id} in PUT forward mode. current time: #{@time}"
		when :retry 
			next_hop = response[:data][:next_hop]
			verify_neighbors(nodeID, next_hop)
			queue(@time+1, @current_event_id, :update_nbrs, next_hop) 
			@stats[:message_log][@current_event_id] << [@time, :retry]
			queue(@time+2, @current_event_id, :send_probe, nodeID, next_hop, response[:data][:new_probe])
		when :failure
			# record reason for failure in both cases. then retry if that's
			# what was specified. 
			@stats[:message_log][@current_event_id] << [@time, response[:error]]
		when :success
			@stats[:message_log][@current_event_id] << [@time, :success]
			delta_t = response[:data][:probe].end_time - response[:data][:probe].start_time
			@stats[:avg_put_time] = Float(@stats[:lms_put_successes]*@stats[:avg_put_time]+ 
										  delta_t)/Float(@stats[:lms_put_successes]+1)
			delta_t_reply = @time - response[:data][:probe].end_time
			@stats[:message_log][@current_event_id] << [@time, "reply time = #{delta_t_reply}"]
			@stats[:avg_put_reply_time] = (Float(@stats[:lms_put_successes])*Float(@stats[:avg_put_reply_time])+ 
										  delta_t_reply)/Float(@stats[:lms_put_successes]+1)
			@stats[:lms_put_successes] += 1 
			location_stored = response[:data][:probe].path.last
			key_stored = response[:data][:probe].orig_key
			@stats[:put_locations][key_stored] << location_stored
		else
			raise UnknownEventError
		end
	end

	# LMS-specific statistics:

	def stats_get
		info = {}
		get_logs = @stats[:message_log].reject{|k,v| v[0][1] != :get_init}
		info[:num_messages] = get_logs.length

		num_dropped = get_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :dropped}}
		info[:num_dropped] = num_dropped

		num_success = get_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :success}}
		info[:num_success] = num_success

		num_isolated= get_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :isolated}}
		info[:num_isolated] = num_isolated

		num_lost = get_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :lost}}
		info[:num_lost]= num_lost
		
		num_missing= get_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :missing}}
		info[:num_missing] = num_missing

		return info
	 
	end


	def stats_put
		info = {}
		put_logs = @stats[:message_log].reject{|k,v| v[0][1] != :put_init}
		info[:num_messages] = put_logs.length

		num_dropped = put_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :dropped}}
		info[:num_dropped] = num_dropped

		num_success = put_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :success}}
		info[:num_success] = num_success

		num_isolated= put_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :isolated}}
		info[:num_isolated] = num_isolated

		num_lost = put_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :lost}}
		info[:num_lost] = num_lost
		
		num_full= put_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :full}}
		info[:num_full] = num_full
		
		num_duplicate= put_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :duplicate}}
		info[:num_duplicate] = num_duplicate
		
		num_retry= put_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :retry}}
		info[:num_retry] = num_retry

		return info
	end

	def print_stats

		randid = rand(36**8).to_s(36) 
		log = File.open("logs/#{randid}.log", "w")

		log.puts "\t\t\t#{@title}"
		log.puts "============================================================="

		log.puts "\t\t\tExperiment Results"
		log.puts "\t\t\tJoin: #{@join}, Part: #{@part}, Move: #{@move}"
		log.puts "\t\t\tWidth: #{@width}, Height: #{@height}, Num_nodes: #{@nodes.length}"

		log.puts "============================================================="
		

		log.puts "\t\t\tAverages"
		log.puts "============================================================="
		
		log.puts "avg_put_time\t\t\t#{@stats[:avg_put_time]}"
		log.puts "avg_put_reply_time\t\t#{@stats[:avg_put_reply_time]}"
		log.puts "avg_get_time\t\t\t#{@stats[:avg_get_time]}"
		log.puts "avg_get_reply_time\t\t#{@stats[:avg_get_reply_time]}"
		log.puts "avg_neighbors\t\t\t#{@stats[:avg_neighbors]}"
		log.puts "neighbor updates\t\t#{@stats[:neighbor_updates]}"
		log.puts "avg_density\t\t\t#{@stats[:avg_density]}"
		log.puts "Total messages\t\t\t#{@stats[:message_log].length}"

		
		log.puts "\n\t\t\tPut Statistics"
		log.puts "============================================================="
		
		put_logs = @stats[:message_log].reject{|k,v| v[0][1] != :put_init}
		log.puts "Total Put Messages = #{put_logs.length}"

		num_dropped = put_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :dropped}}
		log.puts "num_dropped = #{num_dropped}"

		num_success = put_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :success}}
		log.puts "num_success= #{num_success}"

		num_isolated= put_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :isolated}}
		log.puts "num_isolated= #{num_isolated}"

		num_lost = put_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :lost}}
		log.puts "num_lost= #{num_lost}"
		
		num_full= put_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :full}}
		log.puts "num_full= #{num_full}"
		
		num_duplicate= put_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :duplicate}}
		log.puts "num_duplicate= #{num_duplicate}"
		
		num_retry= put_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :retry}}
		log.puts "num_retry= #{num_retry}"

		
		log.puts "\n\t\t\tGet Statistics"
		log.puts "============================================================="
		
		get_logs = @stats[:message_log].reject{|k,v| v[0][1] != :get_init}
		log.puts "Total Get Messages = #{get_logs.length}"

		num_dropped = get_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :dropped}}
		log.puts "num_dropped = #{num_dropped}"

		num_success = get_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :success}}
		log.puts "num_success= #{num_success}"

		num_isolated= get_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :isolated}}
		log.puts "num_isolated= #{num_isolated}"

		num_lost = get_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :lost}}
		log.puts "num_lost= #{num_lost}"
		
		num_missing= get_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :missing}}
		log.puts "num_missing= #{num_missing}"


		log.puts "\t\t\tEvents per unit time"
		log.puts "============================================================="
		log.puts "time\tnum_events"
		per_time = @stats[:events_per_unit_time].sort{|a,b| a[:time]<=>b[:time]}
		per_time.each{|record|
			log.puts "#{record[:time]}\t#{record[:num_events]}"
		}

		log.puts "\n"

		log.puts "\t\t\tEvent Histories"
		log.puts "============================================================="
		# the sort block sorts by the first timestamp in the event history
		@stats[:message_log].sort{|a,b| a[1][0][0]<=>b[1][0][0] }.each{|event_id, history|
			log.puts event_id
			history.each{|time, event|
				log.puts "\tt#{time}: #{event}. "
			}
			log.puts ""
		}

		log.close
	end

end

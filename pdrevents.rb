
module PDREvents

	@@publish_rate = nil
	@@num_publishers = nil
	@@num_subscribers = nil

	def publish_rand(msg_body, predicate)
		# pick a random node to publish a message
		nid = @nodes.keys()[rand(@nodes.length)]
		publish(msg_body, predicate, nid)
	end


	def publish(msg_body, predicate, nodeID)
		# have nodeID setup and keep a record that it sent a message?
		response = @nodes[nodeID].publish msg_body, predicate
		publish_callback(response)
	end

	def publish_callback response
		action = response[:indicator]
		if result == :duplicate
			@stats[:message_log][@current_event_id] << [@time, :duplicate]
		else 
			# count stats about how many have been delivered
			message = response[:message]
			num_destinations = message.num_destinations
			num_delivered = message.num_delivered
			num_subscribers = @subscriptions[message.predicate]
			stats = "stats"
			def stats.data; return {:destinations, num_destinations, :delivered, num_delivered, :subscribers, num_subscribers}; end
			@stats[:message_log][@current_event_id] << [@time, stats]

			if result == :nomatch
				@stats[:message_log][@current_event_id] << [@time, :nomatch]
			elsif result == :forward
				@stats[:message_log][@current_event_id] << [@time, :forward]
				queue(@time+1, @current_event_id, :broadcast, nodeID, :forward, message, :publish_callback)
				# stuff
			end
		end
	end

	def broadcast(fromID, recipient_method, recipient_method_args, callback)
		# identify all neighbors of fromID and call the receiving method on
		# those neigbors. 
		nbrs = get_physical_nbrs(fromID)
		# call recipient_method on each neighbor
		nbrs.each {|nbr|
			result = nbr.send(recipient_method, *recipient_method_args)
			send(callback, result) unless not callback
		}
	end

	def add_subscription num_nodes, predicate
		# keep track of how many subscribers there are for each predicate
		@subscriptions = @subscriptions || {}
		@subscriptions[predicate] = num_nodes
		num_nodes.times {
			nid = @nodes.keys()[rand(@nodes.length)]
			@nodes[nid].add_subscription predicate
		}
	end

	def delete_subscription nid
	end

	def beacon 
		# schedule announce subscriptions, and cleanup own subscriptions
		@nodes.each{|nid, n|
			# beacon_update calls cleanup and summarize
			subscr_summary = n.beacon_update @time
			queue @time+1, @current_event_id, :broadcast, fromID=nid, :predicate_received, 
				[subscr_summary, nid, @time+1], nil
		}
	end

	def stats_put
		info = {}
		published = @stats[:message_log].reject{|k,v| v[0][1] != :publish}
		num_published = published.length
		info[:num_published] = num_published
		puts num_published

		total_msgs = published.inject(0){|sum, item| sum += item.length}
		avg_overhead = total_msgs/num_published
		info[:avg_overhead] = avg_overhead
		puts avg_overhead

		published.each{|msg_id, history| 
			idx = history.rindex{|item| item[1] == "stats"}
			stats = history[idx][1]
			data = stats.data
			puts "stats for message #{msg_id}"
			puts data
		}
		#num_success = put_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :success}}
		#info[:num_success] = num_success

		return info
	end

end


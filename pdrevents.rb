
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
		# queue the next step
		action = response[:indicator]
		if action == :forward
			queue(@time+1, @current_event_id, :broadcast, nodeID, :forward, message, :publish_callback)
		else if action == :duplicate
			# do some accounting and drop the message
		else if action == :nomatch
			# do some accounting and drop the message
		end

	end

	def publish_callback response
		action = response[:indicator]
		if result == :duplicate
			# stuff
		else if result == :nomatch
			# stuff
		else if result == :forward
			queue(@time+1, @current_event_id, :broadcast, nodeID, :forward, message, :publish_callback)
			# stuff
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

end



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
		response = @nodes[nodeID].publish msg_body, predicate, @time
		publish_callback(nodeID, response)
	end

	def publish_callback fromID, response
		action = response[:indicator]
		if action == :duplicate
			# if this message was a duplicate, then there is no new information
			# to record. 
			#@stats[:message_log][@current_event_id] << [@time, :duplicate]
			DESCHEDULE!!
		else 
			# keep a record of the actual subscriptions, of nodes that have
			# been detected as destinations, and all nodes to whom the message
			# has been delivered. 
			message = response[:contents]
			@stats[:messages] = @stats[:messages] || {}

			if not @stats[:messages].include? message.id
				@stats[:messages][message.id] = {:published_at, @time, :last_updated, 
					@time, :predicate, message.predicate, :body, message.body, 
					:destinations, [], :delivered, [], :subscribers, []}
			end
			stats_this_msg = @stats[:messages][message.id]

			# get the data from this version of the message
			global_subscribers = @subscriptions[message.predicate]
			this_copy_destinations = message.destinations
			this_copy_delivered = message.delivered_to

			# append any new info to our stats record (subscribers is a global
			# property, but it's possible for it to be updated during the course
			# of message delivery if new subscriptions are added). 
			stats_this_msg[:subscribers] = stats_this_msg[:subscribers] | global_subscribers
			stats_this_msg[:destinations] = stats_this_msg[:destinations] | this_copy_destinations
			stats_this_msg[:delivered] = stats_this_msg[:delivered] | this_copy_delivered
			stats_this_msg[:last_updated] = @time
			
			# take the necessary action, if any
			if action == :nomatch
				@stats[:message_log][@current_event_id] << [@time, :nomatch]
			elsif action == :forward
				@stats[:message_log][@current_event_id] << [@time, :forward]
				delay = response[:delay]
				queue(@time+1+Integer(delay), @current_event_id, :broadcast, fromID, :forward, [message, @time+1], :publish_callback)
			end
		end
	end

	def update_nbr_stats src_id, new_nbrs
		# store the average number of neighbours (initialized in simulator class)

		# update info
		@nbrlists = @nbrlists || Hash.new {|hash, key| hash[key] = []}
		old_nbrs = @nbrlists[src_id]
		@nbrlists[src_id] = new_nbrs

		@stats[:avg_neighbors] = Float((@stats[:avg_neighbors]*@stats[:neighbor_updates]) + 
								new_nbrs.length)/Float(@stats[:neighbor_updates]+1)

		# store the percent neighbour change
		diff = (old_nbrs - new_nbrs)
		percent_change = Float(diff.length)/Float(old_nbrs.length)
		@stats[:avg_nbr_percent_change] = Float((@stats[:avg_nbr_percent_change]*@stats[:neighbor_updates]) + 
								percent_change)/Float(@stats[:neighbor_updates]+1)
		
		# NOW update the count of neighbour updates
		@stats[:neighbor_updates] += 1
	end

	def broadcast(fromID, recipient_method, recipient_method_args, callback)
		# identify all neighbors of fromID and call the receiving method on
		# those neigbors. 
		nbrs = get_physical_nbrs(fromID)
		update_nbr_stats fromID, nbrs
		# call recipient_method on each neighbor
		nbrs.each {|nbr|
			result = @nodes[nbr].send(recipient_method, *recipient_method_args)
			# whatever the result was, annotate it with the originating node's
			# ID. 
			send(callback, fromID=nbr, result) unless not callback
		}
	end

	def add_subscription num_nodes, predicate
		# keep track of subscribers for each predicate. this is used for
		# delivery accounting and also to make sure subscriptions are added to
		# nodes that aren't already subscribed to the given rpedicate (even if
		# the subscription request occurs at a future time). 
		@subscriptions = @subscriptions || {}
		@subscriptions[predicate] = @subscriptions[predicate] || []
		successful = 0
		while successful < num_nodes
			nid = @nodes.keys()[rand(@nodes.length)]
			if @subscriptions[predicate].include? nid
				next
			else
				@subscriptions[predicate] << nid
				@nodes[nid].add_subscription predicate
				successful += 1
			end
		end
	end

	def delete_subscription nid
	end

	def beacon 
		# schedule announce subscriptions, and cleanup own subscriptions
		@nodes.each{|nid, n|
			# beacon_update calls cleanup and summarize
			subscr_summary = n.beacon_update @time
			# if the node has any subscriptions, queue delivery of beacon
			queue @time+1, @current_event_id, :broadcast, fromID=nid, :predicate_received, 
				[subscr_summary, nid, @time+1], nil if subscr_summary
		}
	end

	def stats_put
		info = {}
		published = @stats[:message_log].reject{|k,v| v[0][1] != :publish_rand}
		num_published = published.length
		info[:num_published] = num_published
		puts "num published = #{num_published}"

		total_packets = published.inject(0){|sum, item| sum += item[1].length}
		puts "total 'packets' sent for all msgs: #{total_packets}"
		avg_overhead = Float(total_packets)/Float(num_published)
		info[:avg_overhead] = avg_overhead
		puts "avg overhead = #{avg_overhead}"

		puts "average number of neighbors: #{@stats[:avg_neighbors]}"
		puts "average % neighbor change: #{@stats[:avg_nbr_percent_change]}"

		sorted_msgs = @stats[:messages].sort{|a, b| a[1][:published_at] <=> b[1][:published_at]}
		sorted_msgs.each{|msg_id, data| 
			puts "Time #{data[:published_at]}, message id #{msg_id} (#{data[:predicate]}: #{data[:body]})"
			puts "destinations, subscribers, delivered, total_time"
			puts "#{data[:subscribers].length}, #{data[:destinations].length}, #{data[:delivered].length}, #{data[:last_updated]-data[:published_at]}"
		}
		#num_success = put_logs.inject(0){|sum, item| sum += item[1].count{|x| x.include? :success}}
		#info[:num_success] = num_success

		return info
	end

end


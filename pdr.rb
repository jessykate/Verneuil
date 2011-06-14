# proximity-driven routing implementation
# Verneuil module to be included in Node class

class Message
	def init predicate, body, credits = 0
		# neat way to generate a short uniq id (uses base 36), from
		# http://blog.logeek.fr/2009/7/2/creating-small-unique-tokens-in-ruby
		@id = rand(36**8).to_s(36) 
		@credits = credits
		@predicate = predicate
		@body = body
		@destination_list = {}
	end
	attr_reader :predicate, :body, :id
	attr_accessor :credits

	def set_proximity id, proximity
		# not 100% sure the destination list will be implemented as a hash, so
		# keeping this method as the interface for now
		@destination_list[id] = proximity
	end

	def get_proximity id
		# will return nil if destination list does not include id
		if @destination_list.key? id
			return @destination_list[id]
		else
			return 0
		end
	end
		
	def add_destination 
		@destination_list[id] = prox
	
	end
	
	def destination_include? id
		if @destination_list[id] 
			return true
		else 
			return false
		end
	end
end

module PDR

	@@beacon_interval = nil
	@@message_ids_received = []
	@@delay_factor = nil
	@@timeout = nil
	@@credits = nil

	def self.setup beacon_interval, delay_factor, timeout, credits = 0
		# time between beacon updates. set to 5 seconds in the PDR paper. 
		@@beacon_interval = beacon_interval

		# multiplicative factor to scale the proximity value - determines how
		# long a node waits before forwarding a message. 
		@@delay_factor = delay_factor

		# the number of beacon intervals after which a record is removed from
		# the proximity table. 
		@@timeout = timeout

		# number of times to forward even though proximity criteria have not been met
		@@credits = credits
	end

	def publish msg_body, predicate
		# publish a message containing msg_body and associate it with the given
		# predicate.
		message = Message.new predicate, msg_body, @@credits
		@messages_published << message
		# send the message to this node first, which will check for local
		# subscriptions and initialize the message with a destination list of
		# nodes known to have subscriptions matching this predicate. the
		# destination list stores the id, and the lowest proximity value for
		# that id, known to this node. 
		return forward message end

	def add_subscription predicate
		@st || @st = []
		# subscription table stored predicate, application_id pairs. we don't
		# need the app ID since we're only testing the routing protocol, so
		# just store a 0. 
		@st << [predicate, 0]
	end

	def delete_subscription predicate
		@st.delete_if{|v| v[0] == predicate}
	end

	def summarize 
		summary = []
		@st.each {|pred, id|
			summary << pred
		}
		return summary
	end

	def predicate_received pred_list, broker_id, current_time
		# add/update the item for this broker (note in this implementation, a
		# broker can only have one predicate, but each predicate is a summary
		# of a given node's subscriptions 
		
		# the proximity table stores the actual time, which allows the
		# proximity value to be computed at any time.
		@pt = @pt || {}
		@pt[broker_id] = [pred_list, current_time]
	end

	def cleanup current_time
		to_remove = []
		# proximity is a value between 0 and 1 representing how recently we
		# heard from id, or nil if the time has exceeded the timeout threshold. 
		@pt.each {|id, pred_list, last_seen_time|
			to_remove << id if not proximity(current_time - last_seen_time) 
		}
		to_remove.each{|id|
			@pt.delete(id)
		}
	end

	def beacon_update current_time
		# periodic update function. removes expired subscriptions from
		# proximity table and broadcasts this node's current subscription list.
		cleanup current_time
		return summarize
	end

	def proximity(time_delta)
		# the proximity value is infinite if broker b is not present in this
		# node’s proximity table; otherwise it is a value in the range [0,1]
		# calculated as the number of beacons missed from b, divided by the
		# timeout. 

		# time_delta and beacon_interval are both integers so intervals will round
		# down, which is what we want. 
		intervals = time_delta / @@beacon_interval
		if intervals > @@timeout
			return nil
		else
			return intervals/@@timeout
		end
	end

	def forward message
		# returns a response of this form
		response = {:indicator, nil, :contents, nil}
		if @messages_received.include? message.id 
		   response[:indicator] = :duplicate
		   return response
		end

		# check if the message matches any subscriptions on THIS node
		@st.each{|predicate, id|
			if predicate == message.predicate
				# setting the proximity to -1 is used as an indicator that the
				# message was delivered, since no calculated proximity will
				# ever be less than -1. 
				message.set_proximity(@nid, -1)
			end	
		}

		# see if we know about any other nodes interested in this predicate. if
		# this is the originating node, this block actually initializes the
		# destination list. 
		min_proximity = 1
		matched_at_least_one = false
		@pt.each{|id,pred_list,time|
			# p is a proximity value between 0 and 1 representing when we last
			# heard from node id
			p = proximity(time)
			if predicate == message.predicate and (
				not message.destination_include? id or p < message.get_proximity(id)
				)
				matched_at_least_one = true
				message.set_proximity(id, p)
				# keep track of the min_proximity we've seen
				min_proximity = p if min_proximity > p
			end
		}
		if not matched and message.credits > 0
			message.credits -= 1
			matched = true
		end

		# if we had any matches, schedule the message for transmission at a
		# delay proportional to min_proximity
		if matched
			response[:indicator] = :forward
			response[:contents] = message
		else
			response[:indicator] = :nomatch
		end
	end

end


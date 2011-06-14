#!/usr/bin/ruby

require 'sim-util'

experiment_description = "movement only"
params = {
	# LMS parameters,
	:hops => 1,
	:lambda_ => 256,
	:max_failures => 5,
	:randWalkRange => 10,
	:randWalkMin => 25,
	:reply_ttl => 1000,

	# node parameters,
	:broadcastRange => 5,
	:broadcastMin => 15,
	:bufferRange => 10,
	:bufferMin => 10,

	# simulation dynamics,
	:width => 100,
	:height => 100,
	:move => false, # THIS IS THE CONTROLLED VARIABLE
	:join => 0,
	:part => 0,
	:initial_nodes => 200,
	:num_puts => 200,
	:num_gets => 200,
	:wait_time => 10,
}

movement_probabilities = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0] 
simple_experiment_set experiment_description, params, :move, movement_probabilities

exit

experiment_description = "join and part"
params = {
	# LMS parameters,
	:hops => 1,
	:lambda_ => 256,
	:max_failures => 5,
	:randWalkRange => 10,
	:randWalkMin => 25,
	:reply_ttl => 1000,

	# node parameters,
	:broadcastRange => 5,
	:broadcastMin => 15,
	:bufferRange => 10,
	:bufferMin => 10,

	# simulation dynamics,
	:width => 100,
	:height => 100,
	:move => 0.5, # THIS IS THE CONTROLLED VARIABLE
	:join => false,
	:part => false,
	:initial_nodes => 200,
	:num_puts => 200,
	:num_gets => 200,
	:wait_time => 10,
}

join_part_probabilities = [0.0, 0.01, 0.02, 0.05, 0.1, 0.2, 0.3, 0.4, 0.5]
simple_experiment_set experiment_description, params, :join_part, join_part_probabilities

experiment_description = "density"
params = {
	# LMS parameters,
	:hops => 1,
	:lambda_ => 256,
	:max_failures => 5,
	:randWalkRange => 10,
	:randWalkMin => 25,
	:reply_ttl => 1000,

	# node parameters,
	:broadcastRange => 5,
	:broadcastMin => 15,
	:bufferRange => 10,
	:bufferMin => 10,

	# simulation dynamics,
	:width => 100,
	:height => 100,
	:move => 0.5, # THIS IS THE CONTROLLED VARIABLE
	:join => 0,
	:part => 0,
	:initial_nodes => false,
	:num_puts => 200,
	:num_gets => 200,
	:wait_time => 10,
}

num_nodes = [10, 20, 50, 100, 200, 300, 400, 500, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000] 
simple_experiment_set experiment_description, params, :num_nodes, num_nodes


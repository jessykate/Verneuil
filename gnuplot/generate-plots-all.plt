
set terminal png size 500,400

set title "LMS Movement - Neighbor Saturation\n(Avg. Degree = 198/200)"
set xlabel "Move probability"
set ylabel "Percent Success"
set output "move-nbr-saturation.png"
plot "./move-dynamics.tab" using 1:2 index 0 title "PUT" with linespoints, "./move-dynamics.tab" using 1:2 index 1 title "GET" with linespoints

set title "LMS Time Performance\nNeighbor Saturation\n(Avg. Degree = 198/200)"
set xlabel "Move Probability"
set ylabel "Time to Local Minima"
set output "move-nbr-saturation-timeperf.png"
plot "./time-dynamics.tab" using 1:2 index 0 title "PUT" with linespoints, "./time-dynamics.tab" using 1:2 index 1 title "GET" with linespoints

set title "LMS Movement\nPUT and GET close in time\n(Avg. Degree = 9/200)"
set xlabel "Move probability"
set ylabel "Percent Success"
set output "move-put-get-similar-time.png"
plot "./move-dynamics-avgnbr9.tab" using 1:2 index 0 title "PUT" with linespoints, "./move-dynamics-avgnbr9.tab" using 1:2 index 1 title "GET" with linespoints

set title "LMS Time Performance\nPUT and GET close in time\n(Avg. Degree = 9/200)"
set xlabel "Move probability"
set ylabel "Time to Local Minima"
set output "move-put-get-similar-time-timeperf.png"
plot "./time-perf-movement-avgnbr9.tab" using 1:2 index 0 title "PUT" with linespoints, "./time-perf-movement-avgnbr9.tab" using 1:2 index 1 title "GET" with linespoints

set title "LMS Movement\nPUT and GET far in time\n(Avg. Degree = 9/200)"
set xlabel "Move probability"
set ylabel "Percent Success"
set output "move-put-get-far-time.png"
plot "./move-dynamics-avgnbr9-large-get-delta.tab" using 1:2 index 0 title "PUT" with linespoints, "./move-dynamics-avgnbr9-large-get-delta.tab" using 1:2 index 1 title "GET" with linespoints

set title "LMS Time Performance\nPUT and GET far in time\n(Avg. Degree = 9/200)"
set xlabel "Move probability"
set ylabel "Time to Local Minima"
set output "move-put-get-far-time-timeperf.png"
plot "./time-perf-movement-avgnbr9-large-get-delta.tab" using 1:2 index 0 title "PUT" with linespoints, "./time-perf-movement-avgnbr9-large-get-delta.tab" using 1:2 index 1 title "GET" with linespoints

set title "LMS Join and Part\n(movement = 0.5, Avg. Degree = 9/200)"
set xlabel "Move probability"
set ylabel "Percent Success"
set output "part-dynamics.png"
plot "./part-dynamics-avgnbr9.tab" using 1:2 index 0 title "PUT" with linespoints, "./part-dynamics-avgnbr9.tab" using 1:2 index 1 title "GET" with linespoints

set title "LMS Time Performance\nJoin and Part\n(movement = 0.5, Avg. Degree = 9/200)"
set xlabel "Move probability"
set ylabel "Time to Local Minima"
set output "part-dynamics-timeperf.png"
plot "./time-perf-part-avgnbr9.tab" using 1:2 index 0 title "PUT" with linespoints, "./time-perf-part-avgnbr9.tab" using 1:2 index 1 title "GET" with linespoints

set title "LMS Density\n(movement = 0.5, network size = 1000)"
set xlabel "Network Density"
set ylabel "Percent Success"
set output "density-dynamics.png"
plot "./density-dynamics.tab" using 1:2 index 0 title "PUT" with linespoints, "./density-dynamics.tab" using 1:2 index 1 title "GET" with linespoints

set title "LMS Time Performance Density\n(movement = 0.5, network size = 1000)"
set xlabel "Move probability"
set ylabel "Time to Local Minima"
set output "density-dynamics-timeperf.png"
plot "./time-perf-density-dynamics.tab" using 1:2 index 0 title "PUT" with linespoints, "./time-perf-density-dynamics.tab" using 1:2 index 1 title "GET" with linespoints


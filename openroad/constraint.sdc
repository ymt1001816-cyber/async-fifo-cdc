# constraint.sdc : timing constraints for async_fifo, including the clock-domain crossings (OpenSTA)
#   wclk and rclk are unrelated clocks (no fixed phase), so a crossing path has no meaningful setup check.
#   Not a blanket set_false_path / set_clock_groups -asynchronous: the Gray pointer only works if its bits
#   reach the synchronizer within one destination clock period of each other (otherwise two bits can change
#   inside one sampling window and the pointer is seen wrong). set_max_delay bounds that skew; the memory
#   read path wclk -> rdata is bounded the same way.
set wper 4.0                                 ;# 250 MHz write clock
set rper 6.3                                 ;# ~159 MHz read clock, not a multiple of wper
create_clock -name wclk -period $wper [get_ports wclk]
create_clock -name rclk -period $rper [get_ports rclk]
set min_per [expr {min($wper, $rper)}]

# clock-domain crossings: datapath delay only (clock latency ignored), at most one period of the faster clock
set_max_delay $min_per -ignore_clock_latency -from [get_clocks wclk] -to [get_clocks rclk]
set_max_delay $min_per -ignore_clock_latency -from [get_clocks rclk] -to [get_clocks wclk]
# hold has no meaning between unrelated clocks: the synchronizer handles a value that changes at the edge
set_false_path -hold -from [get_clocks wclk] -to [get_clocks rclk]
set_false_path -hold -from [get_clocks rclk] -to [get_clocks wclk]

# resets are asynchronous assertion; their deassertion timing is a separate topic (reset synchronizer)
set_false_path -from [get_ports {wrst_n rrst_n}]

# I/O: each port belongs to one clock domain
set_input_delay  0.5 -clock wclk [get_ports {winc wdata[*]}]
set_output_delay 0.5 -clock wclk [get_ports wfull]
set_input_delay  0.5 -clock rclk [get_ports rinc]
set_output_delay 0.5 -clock rclk [get_ports {rempty rdata[*]}]

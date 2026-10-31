# cdc_report.tcl : timing of the clock-domain-crossing paths in the final layout (run with openroad -exit)
#   env: ODB (6_final.odb), SDC (6_final.sdc), LIB (liberty file)
read_db $::env(ODB)
read_liberty $::env(LIB)
read_sdc $::env(SDC)
if {[file exists $::env(SPEF)]} { read_spef $::env(SPEF) }
foreach {from to} {wclk rclk rclk wclk} {
    puts "== worst crossing path $from -> $to (set_max_delay)"
    report_checks -from [get_clocks $from] -to [get_clocks $to] -path_delay max -format end
    report_checks -from [get_clocks $from] -to [get_clocks $to] -path_delay max -fields {fanout} -digits 3
}
puts "== worst path inside each clock domain"
report_checks -from [get_clocks wclk] -to [get_clocks wclk] -format end
report_checks -from [get_clocks rclk] -to [get_clocks rclk] -format end

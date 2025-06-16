# QuestaSim script to view RX path signals
# Adds key modules along the receiving path with dividers

# QSFP input from testbench
add wave -divider {TOP}
add wave -group TOP -position insertpoint sim:/top_tb/*

add wave -divider {RoCE_minimal_stack}
add wave -group RoCE_minimal_stack -position insertpoint sim:/top_tb/core_inst/RoCE_minimal_stack_512_instance/*

add wave -divider {udp_complete}
add wave -group udp_complete -position insertpoint sim:/top_tb/core_inst/udp_complete_inst/*

add wave -divider {ip_complete}
add wave -group ip_complete -position insertpoint sim:/top_tb/core_inst/udp_complete_inst/ip_complete_inst/*

add wave -divider {eth_axis_tx}
add wave -group eth_axis_tx -position insertpoint sim:/top_tb/core_inst/eth_axis_tx_inst/*

add wave -divider {ip_arb_mux}
add wave -group ip_arb_mux -position insertpoint sim:/top_tb/core_inst/udp_complete_inst/ip_arb_mux_inst/*

run 15 us


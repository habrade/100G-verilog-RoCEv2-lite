# QuestaSim script to view RX path signals
# Adds key modules along the receiving path with dividers

# QSFP input from testbench
add wave -divider {TOP}
add wave -group TOP -position insertpoint sim:/top_tb/*

add wave -divider {RoCE_minimal_stack}
add wave -group RoCE_minimal_stack -position insertpoint sim:/top_tb/core_inst/RoCE_minimal_stack_512_instance/*

add wave -divider {RoCE_qp_state_module}
add wave -group RoCE_qp_state_module -position insertpoint sim:/top_tb/core_inst/RoCE_minimal_stack_512_instance/RoCE_qp_state_module_instance/*

add wave -divider {udp_complete}
add wave -group udp_complete -position insertpoint sim:/top_tb/core_inst/udp_complete_inst/*

add wave -divider {ip_complete}
add wave -group ip_complete -position insertpoint sim:/top_tb/core_inst/udp_complete_inst/ip_complete_inst/*

add wave -divider {eth_axis_tx}
add wave -group eth_axis_tx -position insertpoint sim:/top_tb/core_inst/eth_axis_tx_inst/*

add wave -divider {udp_comp_ip_arb_mux}
add wave -group udp_comp_ip_arb_mux -position insertpoint sim:/top_tb/core_inst/udp_complete_inst/ip_arb_mux_inst/*

add wave -divider {ip_comp_ip_arb_mux}
add wave -group ip_comp_ip_arb_mux -position insertpoint sim:/top_tb/core_inst/udp_complete_inst/ip_complete_inst/ip_arb_mux_inst/*

add wave -divider {ip_comp_ip}
add wave -group ip_comp_ip -position insertpoint sim:/top_tb/core_inst/udp_complete_inst/ip_complete_inst/ip_inst/*

run 20 us


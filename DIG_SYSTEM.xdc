create_clock -period 5.000 -name sys_clk [get_ports Clk]

set_false_path -from [get_ports Input_Raw[*]] -to [get_cells sync_reg_1_reg[*]]

set_property IODELAY_GROUP DIG_SYSTEM_DELAY_GRP [get_cells IDELAYCTRL_inst]
set_property IODELAY_GROUP DIG_SYSTEM_DELAY_GRP [get_cells {GEN_CORES[*].IDELAY_inst}]

create_pblock pblock_DIG_SYSTEM
add_cells_to_pblock [get_pblocks pblock_DIG_SYSTEM] [get_cells {GEN_CORES[*].IDELAY_inst}]
add_cells_to_pblock [get_pblocks pblock_DIG_SYSTEM] [get_cells IDELAYCTRL_inst]
resize_pblock [get_pblocks pblock_DIG_SYSTEM] -add {SLICE_X0Y0:SLICE_X10Y50}

set_property IOSTANDARD LVCMOS33 [get_ports {Input_Raw[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports Clk]
set_property IOSTANDARD LVCMOS33 [get_ports Reset]
set_property IOSTANDARD LVCMOS33 [get_ports Signal_Out]
set_property IOSTANDARD LVCMOS33 [get_ports Lock_Status]
set_property SLEW FAST [get_ports Signal_Out]

set_property IBUF_LOW_PWR FALSE [get_ports {Input_Raw[*]}] 

set_false_path -from [get_ports Reset] -to [get_cells IDELAYCTRL_inst]

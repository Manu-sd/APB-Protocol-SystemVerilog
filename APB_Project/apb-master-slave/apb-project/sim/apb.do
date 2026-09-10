#========================================================
# APB PROJECT - QuestaSim DO FILE
#========================================================

quit -sim

#========================================================
# COMPILE
#========================================================

vlog -sv apb_master.sv
vlog -sv apb_slave.sv
vlog -sv tb_apb_master.sv

#========================================================
# SIMULATION
#========================================================

vsim -voptargs=+acc work.tb_apb_master

#========================================================
# CLOCK & RESET
#========================================================

add wave -divider "CLOCK & RESET"
add wave sim:/tb_apb_master/PCLK
add wave sim:/tb_apb_master/PRESETn

#========================================================
# MASTER INPUTS
#========================================================

add wave -divider "MASTER INPUTS"
add wave sim:/tb_apb_master/req
add wave sim:/tb_apb_master/write
add wave sim:/tb_apb_master/addr
add wave sim:/tb_apb_master/wdata

#========================================================
# MASTER INTERNALS
#========================================================

add wave -divider "MASTER INTERNALS"
add wave sim:/tb_apb_master/master/state
add wave sim:/tb_apb_master/master/next_state
add wave sim:/tb_apb_master/master/addr_reg
add wave sim:/tb_apb_master/master/wdata_reg
add wave sim:/tb_apb_master/master/write_reg

#========================================================
# MASTER OUTPUT
#========================================================

add wave -divider "MASTER OUTPUT"
add wave sim:/tb_apb_master/rdata
add wave sim:/tb_apb_master/done
add wave sim:/tb_apb_master/error

#========================================================
# APB BUS
#========================================================

add wave -divider "APB BUS"
add wave sim:/tb_apb_master/PADDR
add wave sim:/tb_apb_master/PSEL
add wave sim:/tb_apb_master/PENABLE
add wave sim:/tb_apb_master/PWRITE
add wave sim:/tb_apb_master/PWDATA

#========================================================
# SLAVE OUTPUTS
#========================================================

add wave -divider "SLAVE OUTPUTS"
add wave sim:/tb_apb_master/PRDATA
add wave sim:/tb_apb_master/PREADY
add wave sim:/tb_apb_master/PSLVERR

#========================================================
# SLAVE INTERNALS
#========================================================

add wave -divider "SLAVE INTERNALS"
add wave sim:/tb_apb_master/slave/ctrl_sel
add wave sim:/tb_apb_master/slave/status_sel
add wave sim:/tb_apb_master/slave/data_sel
add wave sim:/tb_apb_master/slave/config_sel
add wave sim:/tb_apb_master/slave/addr_valid
add wave sim:/tb_apb_master/slave/wait_count
add wave sim:/tb_apb_master/slave/PREADY

#========================================================
# WAIT STATE
#========================================================

add wave -divider "WAIT STATE"
add wave sim:/tb_apb_master/slave/wait_count

#========================================================
# REGISTERS
#========================================================

add wave -divider "REGISTERS"
add wave sim:/tb_apb_master/slave/CTRL_REG
add wave sim:/tb_apb_master/slave/STATUS_REG
add wave sim:/tb_apb_master/slave/DATA_REG
add wave sim:/tb_apb_master/slave/CONFIG_REG

#========================================================
# RUN
#========================================================

run -all

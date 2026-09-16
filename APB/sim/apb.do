#========================================================
# APB4 PROJECT - QuestaSim DO FILE
#========================================================

quit -sim

#========================================================
# COMPILE
#
# +define+ENABLE_SVA turns on the protocol assertions.
# Remove it for simulators without SVA support.
#========================================================

vlog -sv +define+ENABLE_SVA apb_master.sv
vlog -sv +define+ENABLE_SVA apb_slave.sv
vlog -sv +define+ENABLE_SVA tb_apb_master.sv

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
# MASTER REQUEST INTERFACE
#========================================================

add wave -divider "MASTER REQUEST"
add wave sim:/tb_apb_master/req
add wave sim:/tb_apb_master/write
add wave -radix hex sim:/tb_apb_master/addr
add wave -radix hex sim:/tb_apb_master/wdata
add wave -radix binary sim:/tb_apb_master/strb
add wave -radix binary sim:/tb_apb_master/prot

#========================================================
# MASTER INTERNALS
#========================================================

add wave -divider "MASTER INTERNALS"
add wave sim:/tb_apb_master/master/state
add wave sim:/tb_apb_master/master/next_state
add wave -radix hex sim:/tb_apb_master/master/addr_reg
add wave -radix hex sim:/tb_apb_master/master/wdata_reg
add wave -radix binary sim:/tb_apb_master/master/strb_reg
add wave -radix binary sim:/tb_apb_master/master/prot_reg
add wave sim:/tb_apb_master/master/write_reg

#========================================================
# MASTER OUTPUT
#========================================================

add wave -divider "MASTER OUTPUT"
add wave -radix hex sim:/tb_apb_master/rdata
add wave sim:/tb_apb_master/done
add wave sim:/tb_apb_master/error

#========================================================
# APB4 BUS
#========================================================

add wave -divider "APB4 BUS"
add wave -radix hex sim:/tb_apb_master/PADDR
add wave sim:/tb_apb_master/PSEL
add wave sim:/tb_apb_master/PENABLE
add wave sim:/tb_apb_master/PWRITE
add wave -radix hex sim:/tb_apb_master/PWDATA
add wave -radix binary sim:/tb_apb_master/PSTRB
add wave -radix binary sim:/tb_apb_master/PPROT

#========================================================
# SLAVE OUTPUTS
#========================================================

add wave -divider "SLAVE OUTPUTS"
add wave -radix hex sim:/tb_apb_master/PRDATA
add wave sim:/tb_apb_master/PREADY
add wave sim:/tb_apb_master/PSLVERR

#========================================================
# SLAVE INTERNALS
#========================================================

add wave -divider "SLAVE DECODE"
add wave sim:/tb_apb_master/slave/ctrl_sel
add wave sim:/tb_apb_master/slave/status_sel
add wave sim:/tb_apb_master/slave/data_sel
add wave sim:/tb_apb_master/slave/config_sel
add wave sim:/tb_apb_master/slave/addr_valid
add wave sim:/tb_apb_master/slave/priv_ok
add wave sim:/tb_apb_master/slave/write_ok

#========================================================
# WAIT STATE
#========================================================

add wave -divider "WAIT STATE"
add wave sim:/tb_apb_master/slave/wait_count

#========================================================
# REGISTERS
#========================================================

add wave -divider "REGISTERS"
add wave -radix hex sim:/tb_apb_master/slave/CTRL_REG
add wave -radix hex sim:/tb_apb_master/slave/STATUS_REG
add wave -radix hex sim:/tb_apb_master/slave/DATA_REG
add wave -radix hex sim:/tb_apb_master/slave/CONFIG_REG

#========================================================
# STATUS COUNTERS
#========================================================

add wave -divider "STATUS COUNTERS"
add wave -radix unsigned sim:/tb_apb_master/slave/write_count
add wave -radix unsigned sim:/tb_apb_master/slave/read_count
add wave sim:/tb_apb_master/slave/err_sticky

#========================================================
# RUN
#========================================================

run -all

# Makefile.cdc : cocotb tests for the CDC library (test_cdc.py)
#   make -f Makefile.cdc TOP=pulse_sync | handshake_sync | bus_sync_bug   [COCOTB_RANDOM_SEED=n]
SIM ?= icarus
TOP ?= handshake_sync
TOPLEVEL_LANG = verilog
TOPLEVEL = $(TOP)
COCOTB_TEST_MODULES = test_cdc
VERILOG_SOURCES = $(if $(filter bus_sync_bug,$(TOP)),../formal,../rtl)/$(TOP).v ../rtl/sync2.v ../rtl/async_capture.v
SIM_BUILD = sim_build_$(TOP)
COCOTB_RESULTS_FILE = results_$(TOP).xml
COCOTB_HDL_TIMEPRECISION = 1ps
include $(shell cocotb-config --makefiles)/Makefile.sim

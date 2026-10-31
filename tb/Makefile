# Makefile : cocotb testbench (test_fifo.py) on Icarus Verilog
#   make  [N=words per test]  [COCOTB_RANDOM_SEED=n]
#   make BUG=binary   the planted CDC bug: it PASSES simulation (no metastability in RTL simulation)
# needs OSS CAD Suite (cocotb + iverilog) on PATH:  source ~/tools/oss-cad-suite/environment
SIM ?= icarus
TOPLEVEL_LANG = verilog
TOPLEVEL = async_fifo
COCOTB_TEST_MODULES = test_fifo
ifeq ($(BUG),binary)
VERILOG_SOURCES = ../formal/async_fifo_binary_bug.v ../rtl/sync2.v
SIM_BUILD = sim_build_bug
else
VERILOG_SOURCES = ../rtl/async_fifo.v ../rtl/sync2.v
endif
COCOTB_HDL_TIMEPRECISION = 1ps
include $(shell cocotb-config --makefiles)/Makefile.sim

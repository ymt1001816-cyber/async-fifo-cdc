# config.mk : OpenROAD-flow-scripts (ORFS) design config, open-source RTL-to-GDS for async_fifo (DW = 8, depth 16)
#   run (inside the ORFS image):  make -C $FLOW_HOME DESIGN_CONFIG=<repo>/openroad/config.mk REPO=<repo>
export PLATFORM        = nangate45
export DESIGN_NAME     = async_fifo
export DESIGN_NICKNAME = async_fifo
export VERILOG_FILES   = $(REPO)/rtl/async_fifo.v $(REPO)/rtl/sync2.v $(REPO)/rtl/rst_sync.v
export SDC_FILE        = $(REPO)/openroad/constraint.sdc

export CORE_UTILIZATION = 40
export PLACE_DENSITY    = 0.65

# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(PWD)/tb.v $(PWD)/spiflash.v \
	$(PWD)/tt05_top.v \
	$(PWD)/vga_sync.v \
	$(PWD)/vga_spi_rom.v

# VERILOG_INCLUDE_DIRS += \
# 	$(PWD)/../src

# TOPLEVEL is the name of the toplevel (testbench) module in your Verilog (typically tb.v file):
TOPLEVEL = tb

# MODULE is the basename of the Python test file (i.e. typically from test.py):
MODULE = test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

show:
	gtkwave tb.vcd tb.gtkw

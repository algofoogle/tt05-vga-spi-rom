# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += \
	$(PWD)/test/tb.v \
	$(PWD)/test/spiflash.v \
	$(PWD)/tt05_top.v \
	$(PWD)/vga_sync.v \
	$(PWD)/vga_spi_rom.v

# VERILOG_INCLUDE_DIRS += \
# 	$(PWD)/../src

# TOPLEVEL is the name of the toplevel (testbench) module in your Verilog (typically test/tb.v file):
TOPLEVEL = tb

# See: https://github.com/cocotb/cocotb/discussions/2928
# Allows us to find .py test files in the src/test/ directory:
export PYTHONPATH := ./test

# MODULE is the basename of the Python test file (i.e. typically from test/test.py):
MODULE = test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

show:
	gtkwave tb.vcd utils/tb.gtkw utils/gtkwave.ini

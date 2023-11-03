import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles


# Make sure all bidir pins are configured as outputs
# (as they should always be, for this design):
def check_uio_out(dut):
    assert dut.uio_oe.value == 0b00011011

# This can represent hard-wired stuff:
def set_default_start_state(dut):
    dut.ena.value = 1
    dut.Test_in.value = 1

@cocotb.test()
async def test_basic_waveform_dump(dut):
    """
    Just start a clock, apply reset, and let the design free-run for 500,000 cycles;
    enough to generate at least 1 full VGA frame and dump to VCD
    """

    set_default_start_state(dut)
    # Start with reset released:
    dut.rst_n.value = 1

    cocotb.start_soon(Clock(dut.clk, 40.0, units='ns').start())

    # Wait 3 clocks...
    await ClockCycles(dut.clk, 3)
    check_uio_out(dut)
    # ...then assert reset:
    dut.rst_n.value = 0
    # ...and wait another 3 clocks...
    await ClockCycles(dut.clk, 3)
    check_uio_out(dut)
    # ...then release reset:
    dut.rst_n.value = 1

    # Run the design for 1 line...
    await ClockCycles(dut.clk, 800)
    check_uio_out(dut)

    # ...and another 10 lines...
    await ClockCycles(dut.clk, 10*800)
    check_uio_out(dut)

    # ...then the rest of the frame (525-11 lines)...
    await ClockCycles(dut.clk, 514*800)
    check_uio_out(dut)

    # ...and then a few more of the next frame, to total 500,000 cycles since we came out of reset:
    await ClockCycles(dut.clk, 100*800)
    check_uio_out(dut)


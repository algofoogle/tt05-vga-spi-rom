import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles

@cocotb.test()
async def test_basic_waveform_dump(dut):
    """
    Just start a clock, apply reset, and let the design free-run for 500,000 cycles;
    enough to generate at least 1 full VGA frame and dump to VCD
    """

    cocotb.start_soon(Clock(dut.clk, 40.0, units='ns').start())

    # Start with 'reset' low (released):
    dut.reset.value = 0

    # Wait an arbitrary 150ns...
    await Timer(150, units='ns')
    # ...then assert 'reset':
    dut.reset.value = 1
    # ...and wait another 250ns...
    await Timer(250, units='ns')
    # ...then release 'reset'
    dut.reset.value = 0

    # ...now the design free-runs for another 500,000 cycles:
    await ClockCycles(dut.clk, 500_000)

# `test/`: Files supporting cocotb automated tests

The files in here are those only used by running design verification, i.e. cocotb automated tests.

To actually *run* the tests, however, you want to run `make` in the parent directory (i.e. `src/`, where the `Makefile` is). I kept it in there because this seems to be the convention for Tiny Tapeout projects, and the standard `test` GitHub Action tries to do just this.

Maybe this `test/` dir should instead be called `dv/` (Design Verification)?

The actual files in here include:
*   [tb.v](./tb.v): Verilog test bench which instantiates our TT05 design and provides convenience signals that the tests will use.
*   [spiflash.v](./spiflash.v): Caravel's version of Claire Xenia Wolf's SPI flash ROM simulator; simulates the physical SPI flash ROM we'll have attached to our ASIC.
*   [test_rom.hex](./test_rom.hex): Simulated ROM contents (in `$readmemh` format) that `spiflash` is directed (by `tb`) to use.

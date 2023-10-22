![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg)

# tt05-vga-spi-rom

This is a simple submission for Tiny Tapeout 05 (TT05) which tests reading (and optionally buffering) and displaying data from an attached SPI flash memory (e.g. W25Q80) on a VGA display.

NOTE: At any point in time, this doco might be outdated, and you might find [`info.yaml`](./info.yaml) to
have more recent documentation.

![VGA display showing SPI flash ROM contents](./doc/vga_spi_rom-display.jpg)

NOTE to self: The original version of this code is from my private repo, [here](https://github.com/algofoogle/sandpit/tree/master/fpga/vga_spi_rom).

This repo also includes [`de0nano`](./de0nano/) which is a Quartus project (tested in Quartus Prime Lite Edition version 22.1.0) to wrap the main TT05 `tt_um_algofoogle_vga_spi_rom` design and test it on a DE0-Nano board. That's how I generated the photo above.

NOTE: If you want to read my ramblings as I worked on this and had other thoughts, see [my journal entry about it (0155)](https://github.com/algofoogle/journal/blob/master/0155-2023-10-09.md) and perhaps trace back through older related entries.

# Testing/simulation stuff

Tests are written with cocotb and most of the supporting test files are in `src/test/`, though `src/` (home to `Makefile`) is where you actually run the tests.

The [`test` GitHub Action](.github/workflows/test.yaml) runs the tests. You can check that out to see how it sets up an environment and runs the tests. Here's the short version, though:
1.  Make sure you have a Python 3.6+ environment.
2.  Run `pip install -r requirements.txt`
3.  Install iverilog (I'm using 12.0)
4.  Optional: Install GTKWave
5.  Go into the `src/` dir then run `make` -- this will run the tests, and produce `src/tb.vcd`
6.  Optional: View the VCD file with: `make show`

Included in this repo is [`src/test/spiflash.v`](src/test/spiflash.v) as taken from [efabless/caravel], specifically [here](https://github.com/efabless/caravel/blob/978fa0802312917957ad7186523d946c8cce3c9f/verilog/dv/caravel/spiflash.v), with [a tiny change I made](https://github.com/algofoogle/tt05-vga-spi-rom/commit/5ba4134521c13ea8ac9d2a38b946651ae9f7ab79#diff-0c83aa8e589583dea0f3643cfadedf26aed5a5d9f16f01d74778b87492572f18) so it shows the ROM contents' 32 bytes from the start, rather than 5 bytes taken from the 1MB boundary. This file is only used for automated tests/simulation; it is not part of the synthesised design. The [original code](https://github.com/YosysHQ/picorv32/blob/f00a88c36eaab478b64ee27d8162e421049bcc66/picosoc/spiflash.v) was written by [Claire Xenia Wolf](https://github.com/clairexen). As far as I can tell, the Caravel version that I've included in this repo adds: the [`FILENAME` parameter](https://github.com/efabless/caravel/blob/main/verilog/dv/caravel/spiflash.v#L41); and [support for Continuous Mode](https://github.com/efabless/caravel/blob/978fa0802312917957ad7186523d946c8cce3c9f/verilog/dv/caravel/spiflash.v#L290-L324).

NOTE: `spiflash` doesn't work with a raw binary file. It expects a hex file compatible with `$readmemh()`. One is included: `src/test/test_rom.hex` (and its original binary `src/utils/test_rom.bin` extracted from an ESP-01 module). Note that it does spit out a WARNING:

```
Reading test/test_rom.hex
WARNING: C:/Users/Maurovics/Documents/projects/tt05-vga-spi-rom/src/test/spiflash.v:122: $readmemh(test/test_rom.hex): Not enough words in the file for the requested range [0:16777215].
test/test_rom.hex loaded into memory
spiflash: First 32 bytes:
  e9 03 02 20 20 04 10 40 00 00 10 40 40 07 00 00
  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
```

...but for now I'm not concerned about that because it's only a 1MB SPI ROM that I'm using.


# Repo contents

TBC!


# What is Tiny Tapeout?

TinyTapeout is an educational project that aims to make it easier and cheaper than ever to get your digital designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

The GitHub action will automatically build the ASIC files using [OpenLane](https://www.zerotoasiccourse.com/terminology/openlane/).


## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://discord.gg/rPK2nSjxy8)

[efabless/caravel]: https://github.com/efabless/caravel/tree/main

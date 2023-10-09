![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/wokwi_test/badge.svg)

# tt05-vga-spi-rom

This is a simple submission for Tiny Tapeout 05 (TT05) which tests reading (and optionally buffering) and displaying data from an attached SPI flash memory (e.g. W25Q80) on a VGA display.

![VGA display showing SPI flash ROM contents](./doc/vga_spi_rom-display.jpg)

NOTE to self: The original version of this code is from my private repo, [here](https://github.com/algofoogle/sandpit/tree/master/fpga/vga_spi_rom).

This repo also includes [`de0nano`](./de0nano/) which is a Quartus project (tested in Quartus Prime Lite Edition version 22.1.0) to wrap the main TT05 `tt_um_algofoogle_vga_spi_rom` design and test it on a DE0-Nano board. That's how I generated the photo above.

NOTE: If you want to read my ramblings as I worked on this and had other thoughts, see [my journal entry about it (0155)](https://github.com/algofoogle/journal/blob/master/0155-2023-10-09.md) and perhaps trace back through older related entries.


# What is Tiny Tapeout?

TinyTapeout is an educational project that aims to make it easier and cheaper than ever to get your digital designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

The GitHub action will automatically build the ASIC files using [OpenLane](https://www.zerotoasiccourse.com/terminology/openlane/).


## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://discord.gg/rPK2nSjxy8)


`default_nettype none
`timescale 1ns / 1ps

`include "helpers.v"

// ui_in: Dedicated inputs:
//  ui_in   [0]: SPI io[1] (MISO for simple reads, i.e. data in from SPI memory device).
//  ui_in   [1]: SPI io[2] (input, only used during Quad Fast Read).
//  ui_in   [2]: SPI io[3] (input, only used during Quad Fast Read).
//  ui_in   [3]: vga_mode select: 0=640x480@60Hz, 1=1440x900@60Hz
//  ui_in   [6:4]: TestA[2:0] - 3-input AND gate (outputs to TestA_out)
//  ui_in   [7]: TestB - Loops directly back out to TestB_out
//
// uo_out: Dedicated outputs:
//  uo_out  [0]: hsync
//  uo_out  [1]: vsync
//  uo_out  [2]: red[1]
//  uo_out  [3]: red[2]
//  uo_out  [4]: green[1]
//  uo_out  [5]: green[2]
//  uo_out  [6]: blue[1]
//  uo_out  [7]: blue[2]
//
// uio_out: Bidirectional pins used as outputs:
//  uio_out [0]: SPI /CS (Chip Select, active low).
//  uio_out [1]: SPI SCLK (Serial clock out to SPI memory device).
//  uio_out [2]: SPI io[0] (MOSI for simple reads, i.e. command/data from our device to the SPI memory device).
//  uio_out [3]: red[0]
//  uio_out [4]: green[0]
//  uio_out [5]: blue[0]
//  uio_out [6]: TestA_out
//  uio_out [7]: TestB_out

module tt_um_algofoogle_vga_spi_rom (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path -- UNUSED in this design.
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // Our design uses an active HIGH reset:
  wire reset = ~rst_n;

  // All bidirectional pins *except* [2] are fixed outputs for now:
  assign uio_oe[7:3] = 5'b11111;
  assign uio_oe[1:0] = 2'b11;
  // [2] is controlled by the design (as it is SPI io[0]).

  // Loop back ui_in[7] to uio_out[7]. Maybe we can use this for testing delays:
  assign uio_out[7] = ui_in[7];
  // Make a big AND to use up the remaining ui_in pins:
  assign uio_out[6] = &ui_in[6:4];

  // VGA digital RGB333 outputs:
  // The 9 total RGB output bits are split across uo_out and uio_out...
  wire `RGB rgb;
  // Blue:
  assign {uo_out[7:6],uio_out[5]} = rgb[8:6];
  // Green:
  assign {uo_out[5:4],uio_out[4]} = rgb[5:3];
  // Red:
  assign {uo_out[3:2],uio_out[3]} = rgb[2:0];

  // VGA mode selection: 0=640x480@60Hz, 1=1440x900@60Hz
  wire vga_mode = ui_in[3];

  // VGA sync outputs (polarity of each matches whatever vga_mode requires):
  wire vsync, hsync;
  // VSYNC:
  assign uo_out[1] = vsync;
  // HSYNC:
  assign uo_out[0] = hsync;

  // SPI memory I/O...
  wire [3:0] spi_in;
  // SPI /CS:
  wire spi_cs;  //NOTE: Per vga_spi_rom design, active HIGH. Invert for SPI /CS.
  assign uio_out[0] = ~spi_cs;  // Invert spi_cs to make /CS.
  // SPI SCLK:
  wire spi_sclk;
  assign uio_out[1] = spi_sclk;
  // SPI io[0] (aka MOSI):
  assign uio_oe[2] = ~spi_dir0; // Direction for io[0].
  assign uio_out[2] = spi_out0; // Output side.
  assign spi_in[0] = uio_in[2]; // Input side.
  // SPI io[3:1] (fixed inputs):
  assign spi_in[3:1] = ui_in[2:0];
  
  vga_spi_rom vga_spi_rom(
    .clk      (clk),
    .reset    (reset),
    .vga_mode (vga_mode),
    // VGA outputs:
    .hsync    (hsync),
    .vsync    (vsync),
    .rgb      (rgb),
    // SPI memory interface:
    .spi_cs   (spi_cs),
    .spi_sclk (spi_sclk),
    .spi_in   (spi_in),
    .spi_out0 (spi_out0),
    .spi_dir0 (spi_dir0)
  );

endmodule

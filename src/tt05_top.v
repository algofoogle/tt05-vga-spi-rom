`default_nettype none
`timescale 1ns / 1ps

`include "helpers.v"

// ui_in: Dedicated inputs:
//  ui_in   [0]: SPI MISO (data in from SPI memory device).
//
// uo_out: Dedicated outputs:
//  uo_out  [0]: hsync_n
//  uo_out  [1]: vsync_n
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
//  uio_out [2]: SPI MOSI (Control/data from our device to the SPI memory device).
//  uio_out [3]: red[0]
//  uio_out [4]: green[0]
//  uio_out [5]: blue[0]

module tt_um_algofoogle_vga_spi_rom (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // Our design uses an active HIGH reset:
  wire reset = ~rst_n;

  // All bidirectional pins are outputs for now:
  assign uio_oe = 8'b1111_1111;

  // Loop back ui_in[7] to uio_out[7]. Maybe we can use this for testing delays:
  assign uio_out[7] = ui_in[7];
  // Make a big AND to use up the remaining ui_in pins:
  assign uio_out[6] = &ui_in[6:1];

  // VGA digital RGB333 outputs:
  // The 9 total RGB output bits are split across uo_out and uio_out...
  wire `RGB rgb;
  // Blue:
  assign {uo_out[7:6],uio_out[5]} = rgb[8:6];
  // Green:
  assign {uo_out[5:4],uio_out[4]} = rgb[5:3];
  // Red:
  assign {uo_out[3:2],uio_out[3]} = rgb[2:0];

  // VGA sync outputs:
  wire vsync_n, hsync_n;
  // VSYNC:
  assign uo_out[1] = vsync_n;
  // HSYNC:
  assign uo_out[0] = hsync_n;

  // SPI memory I/O:
  wire spi_cs;  //NOTE: Per vga_spi_rom design, active HIGH. Invert for SPI /CS.
  wire spi_sclk, spi_mosi;
  wire spi_miso;
  assign uio_out[0] = ~spi_cs;  // Invert spi_cs to make /CS.
  assign uio_out[1] =  spi_sclk;
  assign uio_out[2] =  spi_mosi;
  assign spi_miso   =  ui_in[0];

  vga_spi_rom vga_spi_rom(
    .clk      (clk),
    .reset    (reset),
    // VGA outputs:
    .hsync_n  (hsync_n),
    .vsync_n  (vsync_n),
    .rgb      (rgb),
    // SPI memory interface:
    .spi_cs   (spi_cs),
    .spi_sclk (spi_sclk),
    .spi_mosi (spi_mosi),
    .spi_miso (spi_miso)
  );

endmodule

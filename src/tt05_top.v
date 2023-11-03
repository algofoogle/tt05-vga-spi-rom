`default_nettype none
`timescale 1ns / 1ps

`include "helpers.v"

// ui_in: Dedicated inputs:
//  ui_in   [0]: vga_mode select: 0=640x480@60Hz, 1=1440x900@60Hz
//  ui_in   [1]: SPI /RST mode select: 1=(assert 1 on SPI /RST); 0=(make SPI /RST an input)
//  ui_in   [2]: Un/Registered outs: 0=unregistered; 1=registered
//  ui_in   [4:3]: (UNUSED)
//  ui_in   [7:5]: Test_in[2:0] - 3-input AND gate (outputs to Test_out)
//
// uo_out: Dedicated outputs:
//  uo_out  [0]: red[1]
//  uo_out  [1]: green[1]
//  uo_out  [2]: blue[1]
//  uo_out  [3]: vsync
//  uo_out  [4]: red[0]
//  uo_out  [5]: green[0]
//  uo_out  [6]: blue[0]
//  uo_out  [7]: hsync
// These are intended to match the Tiny VGA Pmod:
// https://tinytapeout.com/specs/pinouts/
//
// uio_out: Bidirectional pins used as outputs:
//  uio_out [0]: Out: SPI /CS (Chip Select, active low).
//  uio_out [1]: I/O: SPI io[0] (MOSI for simple reads, i.e. command/data from our device to the SPI memory device).
//  uio_out [2]: In:  SPI io[1] (MISO for simple reads, i.e. data in from SPI memory device).
//  uio_out [3]: Out: SPI SCLK (Serial clock out to SPI memory device).
//  uio_out [4]: Out: Test_out
//  uio_out [5]: I/O: SPI /RST
//  uio_out [6]: In:  SPI io[2] (/WP)  (configured always as input, only used during Quad Fast Read).
//  uio_out [7]: In:  SPI io[3] (/HLD) (configured always as input, only used during Quad Fast Read).
// This is based on this SPI Pmod:
// https://digilent.com/reference/pmod/pmodsf3/start


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

  wire spi_rst_pin_mode = ui_in[1];

  assign uio_oe = {
    2'b00,            // [7:6] are inputs.
    spi_rst_pin_mode, // [5] seleted by ui_in[1].
    3'b110,           // [4:3] are outputs, [2] is an input
    ~spi_dir0,        // [1]: Direction for io[0]. vga_spi_rom uses 0=Output; TT needs 1=Output.
    1'b1              // [0] is an output
  };

  assign uio_out[5] = 1'b1; // IF ui_in[1] says this should be asserted as an output, then output 1 (to disable SPI /RST).

  // These are not used as outputs:
  assign uio_out[7:6] = 0;
  assign uio_out[2] = 0;

  // Make a big AND to use up the remaining ui_in pins:
  assign uio_out[4] = &ui_in[7:5];

  // VGA digital RGB222 outputs:
  // The 2 bits of each channel (going out via uo_out) are intended to
  // match the Tiny VGA Pmod: https://tinytapeout.com/specs/pinouts/
  wire `RGB rgb;

  wire reg_outs = ui_in[2];

  // Registered versions of outputs:
  reg `RGB r_rgb;
  reg r_hsync, r_vsync;
  always @(posedge clk) begin
    if (reset) begin
      r_rgb <= 0;
      r_hsync <= 0;
      r_vsync <= 0;
    end else begin
      r_rgb <= rgb;
      r_hsync <= hsync;
      r_vsync <= vsync;
    end
  end

  // Red:
  assign {uo_out[0], uo_out[4]} = reg_outs ? r_rgb[1:0] : rgb[1:0];
  // Green:
  assign {uo_out[1], uo_out[5]} = reg_outs ? r_rgb[3:2] : rgb[3:2];
  // Blue:
  assign {uo_out[2], uo_out[6]} = reg_outs ? r_rgb[5:4] : rgb[5:4];

  // VGA mode selection: 0=640x480@60Hz, 1=1440x900@60Hz
  wire vga_mode = ui_in[0];

  // VGA sync outputs (polarity of each matches whatever vga_mode requires):
  wire vsync, hsync;
  // VSYNC:
  assign uo_out[3] = reg_outs ? r_vsync : vsync;
  // HSYNC:
  assign uo_out[7] = reg_outs ? r_hsync : hsync;

  // SPI memory I/O...
  wire [3:0] spi_in;
  // SPI /CS:
  wire spi_cs;  //NOTE: Per vga_spi_rom design, active HIGH. Invert for SPI /CS.
  assign uio_out[0] = ~spi_cs;  // Invert spi_cs to make /CS.
  // SPI SCLK:
  wire spi_sclk;
  assign uio_out[3] = spi_sclk;
  // SPI io[0] (aka MOSI):
  wire spi_dir0, spi_out0;
  assign uio_out[1] = spi_out0; // Output side.
  assign spi_in[3:0] = {uio_in[7], uio_in[6], uio_in[2], uio_in[1]}; // Input side.
  
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

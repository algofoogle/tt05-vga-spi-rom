`default_nettype none
`timescale 1ns / 1ps

`include "../src/helpers.v"

module de0nano_top(
  input           CLOCK_50, // Onboard 50MHz clock
  output  [7:0]   LED,      // 8 onboard LEDs
  input   [1:0]   KEY,      // 2 onboard pushbuttons
  input   [3:0]   SW,       // 4 onboard DIP switches

  input  [33:0]   gpio0,    //NOTE: For safety these are currently set as input-only.
  input   [1:0]   gpio0_IN,

  inout  [33:0]   gpio1,    // GPIO1
  input   [1:0]   gpio1_IN  // GPIO1 input-only pins
);

  wire pixel_clock;

  // Quartus-generated PLL module, created using this guide:
  // https://www.ece.ucdavis.edu/~bbaas/180/tutorials/using.a.PLL.pdf
  // This PLL is configured to take in our 50MHz clock and produce
  // a slower VGA pixel clock. Depending on test conditions it will
  // either be 25.0000MHz, 25.1750MHz, or ~26.6175MHz.
  pll	pll_inst (
    .inclk0 (CLOCK_50),
    .c0     (pixel_clock)
  );

  // DIP switch no. 1 on the FPGA board selects which vga_mode we want.
  // If switched to "ON", SW[0] is pulled LOW: selects vga_mode 0 (640x480).
  // If switched off, SW[0] is pulled HIGH: selects vga_mode 1 (1440x900).
  wire vga_mode = SW[0];
  wire reg_outs = SW[1];

  // K4..K1 external buttons board (K4 is top, K1 is bottom):
  //NOTE: These buttons are active LOW, so we invert them here to make them active HIGH:
  // wire [4:1] K = ~{gpio1[23], gpio1[21], gpio1[19], gpio1[17]};

  wire rst_n = KEY[0];  // Use DE0-Nano's onboard button 1 as active LOW reset when pressed.

  /*
  DE0-Nano GPIO1 header using VGA333 DAC adapter:

           |     |     | 
           +-----+-----+ 
       G0  |io13 |io12 |  B0
           +-----+-----+ 
       G1  |io11 |io10 |  B1
           +-----+-----+ 
       G2  | io9 | io8 |  B2
           +-----+-----+ 
      GND  | GND |VCCS |  VCC_SYS
           +-----+-----+ 
    HSYNC  | io7 | io6 |  (NC)
           +-----+-----+ 
    VSYNC  | io5 | io4 |  (NC)
           +-----+-----+ 
       R0  | io3 | io2 |  (NC)
           +-----+-----+ 
       R1  | io1 | IN1 |  (NC)
           +-----+-----+ 
       R2  | io0 | IN0 |  (NC)
           +-----+-----+ * PIN 1
  */

  // Unused:
  assign gpio1[  2] = 1'bz;
  assign gpio1[  4] = 1'bz;
  assign gpio1[  6] = 1'bz;

  // RGB333:
  wire [8:0] rgb;
  // Red:
  assign gpio1[  3] = rgb[0]; // Unused in this design.
  assign gpio1[  1] = rgb[1];
  assign gpio1[  0] = rgb[2];
  // Green:
  assign gpio1[ 13] = rgb[3]; // Unused in this design.
  assign gpio1[ 11] = rgb[4];
  assign gpio1[  9] = rgb[5];
  // Blue:
  assign gpio1[ 12] = rgb[6]; // Unused in this design.
  assign gpio1[ 10] = rgb[7];
  assign gpio1[  8] = rgb[8];

  // HSYNC/VSYNC:
  wire hsync, vsync;
  assign gpio1[  5] = vsync;
  assign gpio1[  7] = hsync;

  // My SPI flash ROM chip is wired up to my DE0-Nano as follows:
  /*

                           +-----+-----+
      (ROM pin 6) SCLK  40 |io33 |io32 | 39  N/C
                           +-----+-----+
                   N/C  38 |io31 |io30 | 37  io3 (ROM pin 7)
                           +-----+-----+
      (ROM pin 3)  io2  36 |io29 |io28 | 35  io0 (ROM pin 5) (MOSI)
                           +-----+-----+
                   N/C  34 |io27 |io26 | 33  io1 (ROM pin 2) (MISO)
                           +-----+-----+
      (ROM pin 1)  /CS  32 |io25 |io24 | 31  N/C
                           +-----+-----+
      (ROM pin 4)  GND  30 | GND |3.3V | 29  VCC (ROM pin 8)
                           +-----+-----+
                           |     |     |

  Thus, gpio1 mapping to SPI flash ROM is as follows:

  | gpio1 pin | gpio1[x]  | ROM pin | Function   |
  |----------:|----------:|--------:|------------|
  |     29    |    VCC3P3 |       8 | VCC3P3     |
  |     30    |       GND |       4 | GND        |
  |     31    | gpio1[24] |   (n/c) |            |
  |     32    | gpio1[25] |       1 | /CS        |
  |     33    | gpio1[26] |       2 | io1 (MISO) |
  |     34    | gpio1[27] |   (n/c) |            |
  |     35    | gpio1[28] |       5 | io0 (MOSI) |
  |     36    | gpio1[29] |       3 | io2        |
  |     37    | gpio1[30] |       7 | io3        |
  |     38    | gpio1[31] |   (n/c) |            |
  |     39    | gpio1[32] |   (n/c) |            |
  |     40    | gpio1[33] |       6 | SCLK       |

  */
  // Inputs (signals the memory chip sends to us in quad mode):
  wire [3:0] spi_in = {gpio1[30], gpio1[29], gpio1[26], gpio1[28]};
  // Outputs that our DUT sends to the memory chip:
  wire spi_cs_n, spi_sclk, spi_out0, spi_dir0;
  assign gpio1[33] = spi_sclk;
  assign gpio1[25] = spi_cs_n;
  assign gpio1[28] = (spi_dir0==0) ? spi_out0 : 1'bz; // When dir0==1, gpio1[28] becomes an input, feeding spi_in[0].

  // // CLOCK_50 output on GPIO1 pin 39 (io32, aka GPIO_132):
  // assign gpio1[ 32] = CLOCK_50;
  // // Divided clocks on pins 37, 35, 33: 25, 12.5, 6.25MHz respectively:
  // reg [2:0] div_clocks;
  // always @(posedge CLOCK_50) div_clocks <= div_clocks + 'd1;
  // assign {gpio1[26], gpio1[28], gpio1[30]} = div_clocks;

  // These are not specifically being tested at this stage:
  wire [2:0]  Test_in = 3'b111;
  wire        Test_out; // This goes nowhere for now.

  wire [7:0] uio_oe;
  assign LED = uio_oe;
  assign spi_dir0 = ~uio_oe[1]; // For TT, 1=Output. We want 0=Output (so it's inverted).

  // Low bits of each RGB333 colour channel are not used by this design:
  assign {rgb[6], rgb[3], rgb[0]} = 0;

  wire [1:0] dummy1 = 0;
  wire [2:0] dummy2;
  wire dummy3;

  wire spi_rst_pin_mode = 1'b0;

  // spi_in[3:1]
  // This is the TT05 submission TOP that we're testing:
  tt_um_algofoogle_vga_spi_rom dut (
    .ui_in    ({Test_in, dummy1[1:0], reg_outs, spi_rst_pin_mode, vga_mode}),
    .uo_out   ({hsync, rgb[7], rgb[4], rgb[1], vsync, rgb[8], rgb[5], rgb[2]}),
    .uio_in   ({spi_in[3:2], 3'b000, spi_in[1:0], 1'b0}),
    .uio_out  ({dummy2[2:0], Test_out, spi_sclk, dummy3, spi_out0, spi_cs_n}),
    .uio_oe   (uio_oe),  // oe[1] sets dir for SPI io[0]. These are all also connected to DE0-Nano's LEDs. 1=LED lit.
    .ena      (1'b1),
    .clk      (pixel_clock),
    .rst_n    (rst_n)
  );

endmodule


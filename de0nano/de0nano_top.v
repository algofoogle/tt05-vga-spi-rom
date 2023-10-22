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

  // RGB:
  wire `RGB rgb;
  // Red:
  assign gpio1[  3] = rgb[0];
  assign gpio1[  1] = rgb[1];
  assign gpio1[  0] = rgb[2];
  // Green:
  assign gpio1[ 13] = rgb[3];
  assign gpio1[ 11] = rgb[4];
  assign gpio1[  9] = rgb[5];
  // Blue:
  assign gpio1[ 12] = rgb[6];
  assign gpio1[ 10] = rgb[7];
  assign gpio1[  8] = rgb[8];

  // HSYNC/VSYNC:
  wire hsync, vsync;
  assign gpio1[  5] = vsync;
  assign gpio1[  7] = hsync;

  // My SPI flash ROM chip is wired up to my DE0-Nano as follows:
  wire spi_cs_n, spi_sclk, spi_mosi, spi_miso;
  assign gpio1[33] = spi_sclk;
  assign gpio1[31] = spi_cs_n;
  assign gpio1[29] = spi_mosi;
  assign spi_miso  = gpio1[27];

  // // CLOCK_50 output on GPIO1 pin 39 (io32, aka GPIO_132):
  // assign gpio1[ 32] = CLOCK_50;
  // // Divided clocks on pins 37, 35, 33: 25, 12.5, 6.25MHz respectively:
  // reg [2:0] div_clocks;
  // always @(posedge CLOCK_50) div_clocks <= div_clocks + 'd1;
  // assign {gpio1[26], gpio1[28], gpio1[30]} = div_clocks;

  // These are not specifically being tested at this stage:
  wire [4:0]  TestA = 5'b11111;
  wire        TestB = 1'b0;
  wire        TestA_out, TestB_out; // These go nowhere for now.

  // This is the TT05 submission TOP that we're testing:
  tt_um_algofoogle_vga_spi_rom dut (
    .ui_in    ({TestB, TestA, vga_mode, spi_miso}),
    .uo_out   ({rgb[8:7], rgb[5:4], rgb[2:1], vsync, hsync}),
    .uio_in   (8'b0), // UNUSED.
    .uio_out  ({TestB_out, TestA_out, rgb[6], rgb[3], rgb[0], spi_mosi, spi_sclk, spi_cs_n}),
    .uio_oe   (LED),  // Connect these to DE0-Nano's LEDs. 1=LED lit.
    .ena      (1'b1),
    .clk      (pixel_clock),
    .rst_n    (rst_n)
  );

endmodule


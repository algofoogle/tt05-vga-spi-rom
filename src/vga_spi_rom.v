`default_nettype none
`timescale 1ns / 1ps

`include "helpers.v"


module vga_spi_rom(
  input               clk,
  input               reset,
  // VGA outputs:
  output wire         hsync_n,
  output wire         vsync_n,
  output wire `RGB    rgb,
  // SPI ROM interface:
  output wire         spi_cs,   //NOTE: This is active HIGH.
  output wire         spi_sclk,
  output wire         spi_mosi,
  input  wire         spi_miso
);

  localparam [9:0]    BUFFER_DEPTH      = 128;
  localparam [9:0]    SPI_CMD_LEN       = 8;
  localparam [9:0]    SPI_ADDR_LEN      = 24;
  localparam [9:0]    PREAMBLE_LEN      = SPI_CMD_LEN + SPI_ADDR_LEN;
  localparam [9:0]    STREAM_LEN        = PREAMBLE_LEN + BUFFER_DEPTH; // Number of bits in our full SPI read stream.
  localparam [9:0]    STORED_MODE_HEAD  = 416; // (640-PREAMBLE_LEN) would run preamble (32bits, CMD[7:0] + ADDR[23:0]) to complete at end of 640w line.
  localparam [9:0]    STORED_MODE_TAIL  = STORED_MODE_HEAD + STREAM_LEN;

  // --- VGA sync driver: ---
  wire hsync, vsync;
  wire [9:0] hpos, vpos;
  wire visible;
  wire hmax, vmax;
  vga_sync vga_sync(
    .clk      (clk),
    .reset    (reset),
    .hsync    (hsync),
    .vsync    (vsync),
    .hpos     (hpos),
    .vpos     (vpos),
    .hmax     (hmax),
    .vmax     (vmax),
    .visible  (visible)
  );
  // vga_sync gives active-high H/VSYNC, but VGA needs active-low, so invert:
  assign {hsync_n,vsync_n} = ~{hsync,vsync};

  // Inverted clk directly drives SPI SCLK at full speed, continuously:
  assign spi_sclk = ~clk; 

  // Stored mode or direct mode?
  wire stored_mode = vpos[2]==0;
  // Even 4-line group: stored mode: read MISO to internal memory; deferred display.
  // Odd  4-line group: direct mode: read and display MISO data directly.

  // The 'memory' storing data read from SPI flash ROM, when in stored_mode:
  reg [BUFFER_DEPTH-1:0] data_buffer;

  // SPI states follow hpos, with an offset based on stored_mode...
  //NOTE: +1 makes our case() easier to follow with register lag considered.
  wire [9:0] state = 
    stored_mode ? (hpos - STORED_MODE_HEAD):
                  hpos;

  // This is screen-time when we'd normally be storing from MISO to buffer:
  wire store_data_region = (hpos >= STORED_MODE_HEAD+PREAMBLE_LEN && hpos < STORED_MODE_TAIL);
  // Screen-time when we'd normally display data (directly from MISO, or buffer):
  wire paint_data_region = (hpos > PREAMBLE_LEN && hpos <= STREAM_LEN);
  //NOTE: 'Greater than' (+1 shift) comparison we want to shift data_buffer only AFTER its MSB has been shown.

  //NOTE: posedge of SPI_SCLK, because this is where MISO remains stable...
  always @(posedge spi_sclk) begin
    if (stored_mode) begin
      if (store_data_region) begin
        // Bits are streaming out via MISO, so shift them into data_buffer:
        data_buffer <= {data_buffer[BUFFER_DEPTH-2:0], spi_miso};
      end else if (paint_data_region) begin
        // In stored_mode, but this is the typical display region where we want
        // to SHOW data (in this case from data_buffer): Shift out the bits:
        data_buffer <= {data_buffer[BUFFER_DEPTH-2:0], 1'b0};
      end
    end
  end

  // Chip is ON for the whole duration of our SPI read stream:
  assign spi_cs = state < STREAM_LEN;

  // MOSI depends on a CMD/ADDR 32-bit sequence.
  //NOTE: This could be stored in a vector that we shift (or index),
  // or a case(), or could be a memory array.
  // assign spi_mosi =
  //   (state<  6)               ? 1'b0:           // CMD[7:2] is 'b000000.
  //   (state== 6 || state== 7)  ? 1'b1:           // CMD[1:0] is 'b11.
  //                             //ADDR[23:11] is 0.
  //   (state>=21 && state<=27)  ? vpos[30-state]: // ADDR[10:4] is vpos[9:3]
  //                             //ADDR[3:0] is 0.
  //   (state>=PREAMBLE_LEN)     ? 1'bx:           // Don't care after preamble.
  //                               0;              // Other preamble bits must be 0.

  // // An alternative, but this one is messy on the MOSI line which makes our
  // // display really hard to interpret:
  // wire [4:0] pstate = state[4:0];
  // assign spi_mosi =
  //   (pstate== 6 || pstate== 7)  ? 1:              // CMD[1:0] is 'b11.
  //   (pstate>=21 && pstate<=27)  ? vpos[30-pstate]: // ADDR[10:4] is vpos[9:3]
  //                                 0;              // 0 for all other preamble bits
  //                                                 // and beyond.

  // This alternative seems to be the simplest:
  assign spi_mosi =
    (state== 6 || state== 7)  ? 1'b1:           // CMD[1:0] is 'b11.
    (state>=21 && state<=27)  ? vpos[30-state]: // ADDR[10:4] is vpos[9:3]
                                1'b0;           // 0 for all other preamble bits
                                                // and beyond.

  // On screen, we highlight where byte boundaries would be, by alternating the
  // background colour every 8 horizontal pixels. 'Even bytes' are those where
  // hpos[3]==1; 'odd' when hpos[3]==0.
  wire even_byte = hpos[3];

  // Data comes from...
  wire data =
    stored_mode ? data_buffer[BUFFER_DEPTH-1]:  // ...memory, in stored mode.
                  spi_miso;                     // ...chip, in direct mode.

  wire `RGB pixel_color =
    // Force green pixels during MOSI high:
    spi_mosi  ? 9'b000_111_000:
    // Else, B=/CS, G=data, R=odd/even byte.
                { {3{spi_cs}}, {3{data}}, {3{~even_byte}} };

  // Dividing lines are blacked out, i.e. first line of each address line pair,
  // because they contain buffer junk, but also to make it easier to see pairs:
  wire dividing_line = vpos[2:0]==0;

  assign rgb =
    (!visible)      ? 9'b000_000_000: // Black for blanking.
    (dividing_line) ? 9'b000_000_000: // Black for dividing lines.
                      pixel_color;
  
endmodule

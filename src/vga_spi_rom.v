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
  output reg          spi_cs,   //NOTE: This is active HIGH.
  output              spi_sclk,
  output reg          spi_mosi,
  input  wire         spi_miso
);

  localparam        BUFFER_DEPTH      = 128;
  localparam        SPI_CMD_LEN       = 8;
  localparam        SPI_ADDR_LEN      = 24;
  localparam        PREAMBLE_LEN      = SPI_CMD_LEN + SPI_ADDR_LEN;
  localparam        STREAM_LEN        = PREAMBLE_LEN + BUFFER_DEPTH; // Number of bits in our full SPI read stream.
  localparam [9:0]  STORED_MODE_HEAD  = 408; //(640-PREAMBLE_LEN); // Run the preamble (32bits, i.e. CMD[7:0] and ADDR[23:0]) to complete at end of 640w line.
  localparam [9:0]  STORED_MODE_TAIL  = STORED_MODE_HEAD + STREAM_LEN;
  localparam [9:0]  DIRECT_MODE_HEAD  = 8;
  localparam [9:0]  DIRECT_MODE_TAIL  = DIRECT_MODE_HEAD + STREAM_LEN;

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
    stored_mode ? (hpos + 1'b1 - STORED_MODE_HEAD):
                  (hpos + 1'b1 - DIRECT_MODE_HEAD);

  // This is screen-time when we'd normally be storing from MISO to buffer:
  wire store_data_region = (hpos >= STORED_MODE_HEAD+PREAMBLE_LEN && hpos < STORED_MODE_TAIL);
  // Screen-time when we'd normally display data (directly from MISO, or buffer):
  wire paint_data_region = (hpos >= DIRECT_MODE_HEAD+PREAMBLE_LEN+1 && hpos <= DIRECT_MODE_TAIL+1);
  //NOTE: +1 because we want to shift data_buffer only AFTER its MSB has been shown.

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

  always @(posedge clk) begin
    // This case() controls SPI signals based on 'state' derived from horizontal
    // pixel position (hpos), with a varying offset...

    // MOSI signals asserted here are sampled by SPI chip on FALLING clk edge,
    // because it's inverted to become the rising SCLK of the SPI memory.

    case (state)
    // Turn chip ON, and commence command 03h (READ)...
      0:    begin spi_mosi <= 0;  spi_cs <= 1;  end // CMD[7], chip ON.
      1:    begin spi_mosi <= 0;                end // CMD[6].
      2:    begin spi_mosi <= 0;                end // CMD[5].
      3:    begin spi_mosi <= 0;                end // CMD[4].
      4:    begin spi_mosi <= 0;                end // CMD[3].
      5:    begin spi_mosi <= 0;                end // CMD[2].
      6:    begin spi_mosi <= 1;                end // CMD[1].
      7:    begin spi_mosi <= 1;                end // CMD[0].
    // Address 000000h:
      8:    begin spi_mosi <= 0;                end // ADDR[23]
      9:    begin spi_mosi <= 0;                end // ADDR[22]
      10:   begin spi_mosi <= 0;                end // ADDR[21]
      11:   begin spi_mosi <= 0;                end // ADDR[20]
      12:   begin spi_mosi <= 0;                end // ADDR[19]
      13:   begin spi_mosi <= 0;                end // ADDR[18]
      14:   begin spi_mosi <= 0;                end // ADDR[17]
      15:   begin spi_mosi <= 0;                end // ADDR[16]
      16:   begin spi_mosi <= 0;                end // ADDR[15]
      17:   begin spi_mosi <= 0;                end // ADDR[14]
      18:   begin spi_mosi <= 0;                end // ADDR[13]
      19:   begin spi_mosi <= 0;                end // ADDR[12]
      20:   begin spi_mosi <= 0;                end // ADDR[11]
      21:   begin spi_mosi <= vpos[9];          end // ADDR[10] <= vpos[9]
      22:   begin spi_mosi <= vpos[8];          end // ADDR[09] <= vpos[8]
      23:   begin spi_mosi <= vpos[7];          end // ADDR[08] <= vpos[7]
      24:   begin spi_mosi <= vpos[6];          end // ADDR[07] <= vpos[6]
      25:   begin spi_mosi <= vpos[5];          end // ADDR[06] <= vpos[5]
      26:   begin spi_mosi <= vpos[4];          end // ADDR[05] <= vpos[4]
      27:   begin spi_mosi <= vpos[3];          end // ADDR[04] <= vpos[3] // Lines are x8 in height since we discard vpos[2:0]
      28:   begin spi_mosi <= 0;                end // ADDR[03] // This and the below bits cover 0..15 bytes per line (actually 15 total by design).
      29:   begin spi_mosi <= 0;                end // ADDR[02]
      30:   begin spi_mosi <= 0;                end // ADDR[01]
      31:   begin spi_mosi <= 0;                end // ADDR[00]
    // First DATA output bit from SPI flash ROM arrives at the NEXT RISING edge of clk (i.e. the FALLING edge of spi_sclk) after 31.
    // 32..159 is then each of 128 bits being read from SPI memory.
    // Turn chip off after reading 128 bits (16 bytes):
      STREAM_LEN:
            begin                 spi_cs <= 0;  end // Chip OFF.
    // MOSI<=0 for all other states so it can't litter display with anything else:
      default:
            begin spi_mosi <= 0;                end
    endcase
  end

  wire blanking = ~visible;

  // On screen, we highlight where byte boundaries would be, by alternating the
  // background colour every 8 horizontal pixels. Hence, 'odd bytes' are those
  // where hpos[3] is set, and 'even' are when hpos[3] is clear.
  wire odd_byte = ~hpos[3]; // Inverted, because on-screen we skip the first 8 pixels.

  // Data comes from...
  wire data =
    stored_mode ? data_buffer[BUFFER_DEPTH-1]:  // ...memory, in stored mode.
                  spi_miso;                     // ...chip, in direct mode.

  wire `RGB pixel_color =
    // Force green pixels during MOSI high:
    spi_mosi  ? 9'b000_111_000:
    // Else, B=/CS, G=data, R=odd/even byte.
                { {3{spi_cs}}, {3{data}}, {3{odd_byte}} };

  // Dividing lines are blacked out, i.e. first line of each address line pair,
  // because they contain buffer junk, but also to make it easier to see pairs:
  wire dividing_line = vpos[2:0]==0;

  assign rgb =
    (blanking)      ? 9'b000_000_000: // Black for blanking.
    (dividing_line) ? 9'b000_000_000: // Black for dividing lines.
                      pixel_color;
  
endmodule

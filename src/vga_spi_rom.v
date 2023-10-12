`default_nettype none
`timescale 1ns / 1ps

`include "helpers.v"

// If MASK_REDUNDANT is defined, a bunch of states that are not explicitly needed are masked out.
//NOTE: My observation has been that *including* these states may actually lead to simpler
// logic, I suppose because the internal comparators can be simpler.
`define MASK_REDUNDANT


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

  localparam        BUFFER_DEPTH = 128;
  localparam        PREAMBLE_LEN = 32; // 8 command bits, 24 address bits.
  localparam        STREAM_LEN = PREAMBLE_LEN+BUFFER_DEPTH; // Number of bits in our full SPI read stream.
  localparam [9:0]  STORED_MODE_START = 448; //(640-PREAMBLE_LEN);

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

  // // Inverted clk directly drives SPI SCLK at full speed, continuously:
  assign spi_sclk = ~clk; 
  // assign spi_sclk = 1'b0;

  // wire stored_mode = vpos[2]==0;  // 

  // This predicts what vpos will be on the next clock cycle. We do this, so
  // we can determine stored_mode_next, i.e. whether we are commencing a stored
  // mode line, or a direct-to-screen line.
  wire [9:0] vpos_next =
    (!hmax) ? vpos:
    (!vmax) ? vpos+1'b1:
              10'd0;
  wire stored_mode_next = vpos_next[2]==0;
  // Even 4-line group: stored mode: read MISO to internal memory; deferred display.
  // Odd  4-line group: direct mode: read and display MISO data directly.

  // This is the 'memory' that stores data read from SPI flash ROM,
  // when we're in stored_mode:
  reg [BUFFER_DEPTH-1:0] data_buffer;

  // SPI states follow hpos, with an offset based on stored_mode...
  //NOTE: +1 makes our case() easier to follow with register lag considered.
  wire [9:0] state = 
    stored_mode_next  ? (hpos + 1'b1 - STORED_MODE_START):
                        (hpos + 1'b1);

  //NOTE: posedge of SPI_SCLK, because this is where MISO remains stable...
  always @(posedge spi_sclk) begin
    if (stored_mode_next) begin
      if (hpos > PREAMBLE_LEN && hpos <= STREAM_LEN) begin
        // We're in the screen region where buffer needs to be displayed,
        // so shift out the bits:
        data_buffer <= {data_buffer[BUFFER_DEPTH-2:0], 1'b0};
      end else if (state > PREAMBLE_LEN && state <= STREAM_LEN) begin
        // We're in the region where bits are streaming out via MISO,
        // so shift them in:
        data_buffer <= {data_buffer[BUFFER_DEPTH-2:0], spi_miso};
      end
    end
  end

  always @(posedge clk) begin
    // This case() controls SPI signals based on 'state' derived from horizontal
    // pixel position (hpos), with a varying offset...
    //
    // In stored_mode, we react at state==0 (which is when hpos==607)
    // by asserting /CS... just as hpos BECOMES 608 (i.e. 640-32).
    //
    // In direct mode, we instead react to state==800 (which is when hpos==799),
    // because it wraps around from 799 to 0, meaning the next state after 800
    // is 1 (skipping 0). Hence, state 800 is equivalent to state 0.

    //NOTE: MOSI signals we assert here take effect on FALLING clk edge, because
    // it is inverted to becoming the rising SCLK of the SPI memory.

    case (state)
    // Turn chip ON, and commence command 03h (READ)...
      // stored_mode:0 and direct:800 represent the same state for CMD[7]:
      0:    if (stored_mode_next)  begin spi_mosi <= 0;  spi_cs <= 1;  end // CMD[7], chip ON.
      800:  if (!stored_mode_next) begin spi_mosi <= 0;  spi_cs <= 1;  end // CMD[7], chip ON.
    `ifndef MASK_REDUNDANT
      1:    begin spi_mosi <= 0;                end // CMD[6].
      2:    begin spi_mosi <= 0;                end // CMD[5].
      3:    begin spi_mosi <= 0;                end // CMD[4].
      4:    begin spi_mosi <= 0;                end // CMD[3].
      5:    begin spi_mosi <= 0;                end // CMD[2].
    `endif
      6:    begin spi_mosi <= 1;                end // CMD[1].
    `ifndef MASK_REDUNDANT
      7:    begin spi_mosi <= 1;                end // CMD[0].
    `endif
    // Address 000000h:
      8:    begin spi_mosi <= 0;                end // ADDR[23]
    `ifndef MASK_REDUNDANT
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
    `endif
      21:   begin spi_mosi <= vpos[9];          end // ADDR[10] <= vpos[9]
      22:   begin spi_mosi <= vpos[8];          end // ADDR[09] <= vpos[8]
      23:   begin spi_mosi <= vpos[7];          end // ADDR[08] <= vpos[7]
      24:   begin spi_mosi <= vpos[6];          end // ADDR[07] <= vpos[6]
      25:   begin spi_mosi <= vpos[5];          end // ADDR[06] <= vpos[5]
      26:   begin spi_mosi <= vpos[4];          end // ADDR[05] <= vpos[4]
      27:   begin spi_mosi <= vpos[3];          end // ADDR[04] <= vpos[3] // Lines are x8 in height since we discard vpos[2:0]
      28:   begin spi_mosi <= 0;                end // ADDR[03] // This and the below bits cover 0..15 bytes per line (actually 15 total by design).
    `ifndef MASK_REDUNDANT
      29:   begin spi_mosi <= 0;                end // ADDR[02]
      30:   begin spi_mosi <= 0;                end // ADDR[01]
      31:   begin spi_mosi <= 0;                end // ADDR[00]
    `endif
    // First DATA output bit from SPI flash ROM arrives at the NEXT RISING edge of clk (i.e. the FALLING edge of spi_sclk) after 31.
    // Turn chip off after reading 128 bits (16 bytes):
      STREAM_LEN:
            begin                 spi_cs <= 0;  end // Chip OFF.
    `ifndef MASK_REDUNDANT
    // Don't care about MOSI for all other states, but 0 is as fine as any:
      default: begin spi_mosi <= 0; end //SMELL: Assign 'x' instead?
    `endif
    endcase
  end

  wire blanking = ~visible;

  // Colour guide:
  // -  Alternate on odd/even 'bytes'.
  // -  Alternate on stored/direct lines.
  // -  For RGB111 use each channel's LSB: 'Subtle' in RGB333 is bold in RGB111.
  //    - This gives us 8 colours (inc. black/white) to work with.
  // -  MOSI should be its own colour... always?
  // -  Do we need to see /CS? Probably *can't* see SCLK.

  // On screen, we highlight where byte boundaries would be, by alternating the
  // background colour every 8 horizontal pixels. Hence, 'even bytes' are those
  // where hpos[3] is clear, and 'odd' are when hpos[3] is set.
  wire even_byte = hpos[3];

  // Data comes from...
  wire data = (hpos >= PREAMBLE_LEN) &
    (stored_mode_next  ? data_buffer[BUFFER_DEPTH-1]:  // ...memory, in stored mode.
                        spi_miso);                     // ...chip, in direct mode.

  wire `RGB pixel_color =
    spi_mosi  ? 9'b000_111_000:
                { {3{spi_cs}}, {3{data}}, {3{even_byte}} };
    // { {3{~stored_mode}}, {3{data}}, {3{~even_byte}} };

  wire dividing_line = vpos[2:0]==0;

  
  // wire `RGB rom_data_color = 
  //   {3'b000, {3{spi_mosi}}, 3'b000} | ( // Show MOSI in the green channel.
  // // Blue byte boundary: White if MISO==1, blue if 0.
  //   (byte_alt==0)   ?(
  //                     (spi_miso==0)?
  //                     { 3'b011,         3'b000,         3'b000  }:  // Dark blue
  //                     { 3'b111,         3'b100,         3'b010  }   // Sky blue
  //                   ):
  // // Red byte boundary: Yellow if MISO==1, dark red if 0.
  //   (spi_miso==0)   ? { 3'b000,         3'b000,         3'b011  }:  // Dark red
  //                     { 3'b000,         3'b100,         3'b111  }   // Strong yellow
  // );

  // wire ram_bit = (vpos[1:0]==0) ? 1'b0 : data_buffer[BUFFER_DEPTH-1];
  // wire `RGB ram_data_color = 
  //   {3'b000, {3{spi_mosi}}, 3'b000} | ( // Show MOSI in the green channel.
  // // Green byte boundary:
  //   (byte_alt==0)   ?(
  //                     (ram_bit==0)?
  //                     { 3'b000,         3'b010,         3'b000  }:  // Dark green
  //                     { 3'b011,         3'b101,         3'b001  }   // Bright green
  //                   ):
  // // Magenta byte boundary:
  //   (ram_bit==0)    ? { 3'b011,         3'b000,         3'b010  }:  // Dark purple
  //                     { 3'b111,         3'b000,         3'b111  }   // Bright magenta
  // );

  // // Even lines are black, so it's easier to see individual bytes:
  // wire `RGB pixel_color =
  //   source_direct ? rom_data_color:
  //                   ram_data_color;
  //                   //(vpos[1:0] == 0) ? 9'd0 : ram_data_color;

  assign rgb =
    (blanking)      ? 9'b000_000_000: // Black for blanking.
    (dividing_line) ? 9'b000_000_000: // Black for dividing lines.
                      pixel_color;
  
endmodule

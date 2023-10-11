`default_nettype none
`timescale 1ns / 1ps

`include "helpers.v"

// If MASK_REDUNDANT is defined, a bunch of states that are not explicitly needed are masked out.
//NOTE: My observation has been that *including* these states may actually lead to simpler
// logic, I suppose because the internal comparators can be simpler.
// `define MASK_REDUNDANT


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

  localparam BUFFER_DEPTH = 128;
  localparam PREAMBLE_LEN = 32; // 8 command bits, 24 address bits.
  localparam STREAM_LEN = PREAMBLE_LEN+BUFFER_DEPTH; // Number of bits in our full SPI read stream.

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
  assign {hsync_n,vsync_n} = ~{hsync,vsync};

  reg byte_alt;           // Colour tint flag to make it easier to see byte boundaries on-screen.

  wire clkb = ~clk;       // Inverted clock, which will be used to drive SPI slave's SCLK at full speed.
  assign spi_sclk = clkb; // Send inverted CLK directly out as SPI SCLK continuously.

  wire source_direct = vpos[2]==1; // True: Read SPI directly to screen. False: Read SPI to internal RAM, display it later.
  // Even-numbered 4-line group; read and display MISO data directly.
  // Odd-numbered 4-line group; read MISO data into internal memory (or a shift buffer) and display that.

  // Used for sharing the main SPI state 'case', regardless of
  // whether we are in source_direct mode (which happens from the start of the scanline),
  // or in or storage mode (which happens from the start of HBLANK):
  wire [9:0] hpos_in_hblank = hpos - (640-1-PREAMBLE_LEN);
  //NOTE: -1 because we check when we're on hpos==639, knowing that it's BECOMING 640 (first HBLANK pixel).
  //NOTE: -PREAMBLE_LEN because we start clocking out the command and address before we hit the critical
  // point where HBLANK starts, which is when we want to start actually capturing the data.
  // If you subtracted MORE than 32, you'd see the MISO data leak onto the screen, or (depending on the design)
  // the contents of the buffer start to change.
  //NOTE: By starting early, we have more time capture more data. In this case I'll just get 128 bits
  // (though I have enough time for 160).

  wire [9:0] state = source_direct ? hpos : hpos_in_hblank;


  //===TBC...===
  // wire stored_mode = vpos[2]==0; // True: Read SPI to internal memory, display it later. False: Read SPI directly to screen.
  // // Manage the offset that is used (during stored_mode) for mapping hpos to SPI transaction states:
  // reg [9:0] state_hpos_offset;
  // always @(posedge clk) begin
  //   if (reset) begin
  //    ...
  //   end
  // end
  // wire [9:0] state = hpos-state_hpos_offset;


  // This is the 'memory' that stores data read from SPI flash ROM,
  // when we're NOT in source_direct mode:
  reg [BUFFER_DEPTH-1:0] data_buffer;

  always @(negedge clk) begin //SMELL: Should we use @(posedge clkb) instead, esp. when shifting from data_buffer to screen?
    if (!source_direct) begin
      //NOTE: Comparisons are off by 1 because we're using NEGEDGE (i.e. after counts have already happened):
      if (hpos > PREAMBLE_LEN && hpos <= STREAM_LEN) begin
        if (hpos > PREAMBLE_LEN+1) begin
          //SMELL: This extra comparison is a bit clunky. Either use a spare bit, or fix the logic
          // to maybe happen in posedge instead of negedge (where it makes more sense).
          //SMELL: Can/should this be done in posedge?
          data_buffer <= {data_buffer[BUFFER_DEPTH-2:0], 1'b0};
        end
      end else begin
        // ram_color_test <= 9'd0; // Turn off green haze.
        if (hpos_in_hblank > PREAMBLE_LEN && hpos_in_hblank <= STREAM_LEN) begin
          // Shift MISO bit into data_buffer:
          //SMELL: Can/should this be done in posedge? Probably not, but maybe `posedge clkb`?
          data_buffer <= {data_buffer[BUFFER_DEPTH-2:0], spi_miso};
        end
      end
    end
  end

  always @(posedge clk) begin

    // THe following case() controls signals on the SPI memory we're controlling, and the 'state' is
    // derived from the horizontal pixel position (hpos). We alternate between that state being based
    // on the start of each line (for direct display of MISO on-screen), and the end of each line
    // (as HBLANK starts, when MISO is being captured in a buffer instead, for displaying
    // as of the next line):
    case (state)
    // Command 03h (READ):
      0:    begin spi_mosi <= 0;  spi_cs <= 1;  byte_alt <= 0; end // CMD[7], chip ON.
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
    `ifndef MASK_REDUNDANT
      28:   begin spi_mosi <= 0;                end // ADDR[03] // This and the below bits cover 0..15 bytes per line (actually 15 total by design).
      29:   begin spi_mosi <= 0;                end // ADDR[02]
      30:   begin spi_mosi <= 0;                end // ADDR[01]
      31:   begin spi_mosi <= 0;                end // ADDR[00]
    // First DATA output bit from SPI flash ROM arrives at the NEXT RISING edge of clk (i.e. the FALLING edge of spi_sclk) after 31.
    // Turn chip off after reading 128 bits (16 bytes):
      STREAM_LEN:
            begin                 spi_cs <= 0;  end // Chip OFF.
    // Don't care about MOSI for all other states, but 0 is as fine as any:
      default: begin spi_mosi <= 0; end
    `endif
    endcase

    // Alternate byte colouring during valid byte display region:
    if ( hpos>=PREAMBLE_LEN && 0==((hpos)&'b111) ) begin
      byte_alt <= ~byte_alt;
    end
  
  end

  wire blanking = ~visible;
  wire border_en = 1'b0; //(hpos=='d0 || hpos=='d639 || vpos=='d0 || vpos=='d479); // Border can help display sync.
  
  wire `RGB rom_data_color = 
    {3'b000, {3{spi_mosi}}, 3'b000} | ( // Show MOSI in the green channel.
  // Blue byte boundary: White if MISO==1, blue if 0.
    (byte_alt==0)   ?(
                      (spi_miso==0)?
                      { 3'b011,         3'b000,         3'b000  }:  // Dark blue
                      { 3'b111,         3'b100,         3'b010  }   // Sky blue
                    ):
  // Red byte boundary: Yellow if MISO==1, dark red if 0.
    (spi_miso==0)   ? { 3'b000,         3'b000,         3'b011  }:  // Dark red
                      { 3'b000,         3'b100,         3'b111  }   // Strong yellow
  );

  wire ram_bit = (vpos[1:0]==0) ? 1'b0 : data_buffer[BUFFER_DEPTH-1];
  wire `RGB ram_data_color = 
    {3'b000, {3{spi_mosi}}, 3'b000} | ( // Show MOSI in the green channel.
  // Green byte boundary:
    (byte_alt==0)   ?(
                      (ram_bit==0)?
                      { 3'b000,         3'b010,         3'b000  }:  // Dark green
                      { 3'b011,         3'b101,         3'b001  }   // Bright green
                    ):
  // Magenta byte boundary:
    (ram_bit==0)    ? { 3'b011,         3'b000,         3'b010  }:  // Dark purple
                      { 3'b111,         3'b000,         3'b111  }   // Bright magenta
  );

  // Even lines are black, so it's easier to see individual bytes:
  wire `RGB pixel_color =
    source_direct ? rom_data_color:
                    ram_data_color;
                    //(vpos[1:0] == 0) ? 9'd0 : ram_data_color;

  assign rgb =
    (blanking)  ? 9'b000_000_000: // Black for blanking.
    (border_en) ? 9'b000_000_111: // Red for border.
                  pixel_color; // Colour determined by bit streaming from ROM.
  
endmodule

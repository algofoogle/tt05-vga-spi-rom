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
  output wire         hsync_n, vsync_n,
  output wire `RGB    rgb,
  // SPI ROM interface:
  output reg          spi_cs,   //NOTE: This is active HIGH.
  output              spi_sclk,
  output reg          spi_mosi,
  input  wire         spi_miso
);

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

  // wire stored_mode = vpos[2]==0; // True: Read SPI to internal memory, display it later. False: Read SPI directly to screen.

  // // Manage the offset that is used (during stored_mode) for mapping hpos to SPI transaction states:
  // reg [9:0] state_hpos_offset;
  // always @(posedge clk) begin
  //   if (reset) begin

  //   end
  // end

  // wire [9:0] state = hpos-state_hpos_offset;

  // Used for sharing the main SPI state 'case', regardless of
  // whether we are in source_direct mode (which happens from the start of the scanline),
  // or in or storage mode (which happens from the start of HBLANK):
  wire [9:0] hpos_in_hblank = hpos - 10'd640;

  // This is the 'memory' that stores data read from SPI flash ROM,
  // when we're NOT in source_direct mode:
  reg [119:0] data_buffer;

  always @(negedge clk) begin //SMELL: Should we use @(posedge clkb) instead, esp. when shifting from data_buffer to screen?
    if (!source_direct) begin
      //NOTE: Comparisons are off by 1 because we're using NEGEDGE (i.e. after counts have already happened):
      if (hpos > 32 && hpos <= 152) begin
        if (hpos > 33) begin
          //SMELL: This extra comparison is a bit clunky. Either use a spare bit, or fix the logic
          // to maybe happen in posedge instead of negedge (where it makes more sense).
          data_buffer <= {data_buffer[118:0], 1'b0};
        end
        // ram_color_test <= hpos[3] ? 9'b000_010_00 : 9'b000_100_000;
      end else begin
        // ram_color_test <= 9'd0; // Turn off green haze.
        if (hpos_in_hblank >32 && hpos_in_hblank <= 152) begin
          // Shift MISO bit into data_buffer:
          //SMELL: Can/should this be done in posedge?
          data_buffer <= {data_buffer[118:0], spi_miso};
        end
      end
    end
  end

  always @(posedge clk) begin
    if (source_direct) begin
      // Even-numbered 4-line group; read and display MISO data directly.
      case (hpos)
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
        27:   begin spi_mosi <= vpos[3];          end // ADDR[04] <= vpos[3] // Lines are x8 since we discard vpos[2:0]
      `ifndef MASK_REDUNDANT
        28:   begin spi_mosi <= 0;                end // ADDR[03] // This and the below bits cover 0..15 bytes per line (actually 15 total by design).
        29:   begin spi_mosi <= 0;                end // ADDR[02]
        30:   begin spi_mosi <= 0;                end // ADDR[01]
        31:   begin spi_mosi <= 0;                end // ADDR[00]
      // First DATA output bit from SPI flash ROM arrives at the NEXT RISING edge of clk (i.e. the FALLING edge of spi_sclk) after 31.
      // Turn chip off after reading and displaying 120 bits (31 bytes):
        152:  begin                 spi_cs <= 0;  end // Chip OFF.
      // Don't care about MOSI for all other states, but 0 is as fine as any:
        default: begin spi_mosi <= 0; end
      `endif
      endcase

    end else begin //!source_direct
      // Odd-numbered 4-line group; read MISO data into internal memory (or a shift buffer) and display that.

      //SMELL: This 'case' could be merged with the one above: MUX hpos/hpos_in_hblank or use an extra state counter reg.
      case (hpos_in_hblank)
      // Command 03h (READ):
        // 0 here is hpos==640:
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
        27:   begin spi_mosi <= vpos[3];          end // ADDR[04] <= vpos[3] // Lines are x8 since we discard vpos[2:0]
      `ifndef MASK_REDUNDANT
        28:   begin spi_mosi <= 0;                end // ADDR[03] // This and the below bits cover 0..15 bytes per line (actually 15 total by design).
        29:   begin spi_mosi <= 0;                end // ADDR[02]
        30:   begin spi_mosi <= 0;                end // ADDR[01]
        31:   begin spi_mosi <= 0;                end // ADDR[00]
      // First DATA output bit from SPI flash ROM arrives at the NEXT RISING edge of clk (i.e. the FALLING edge of spi_sclk) after 31.
      // Turn chip off after reading and storing 120 bits (31 bytes):
        // 152 here is hpos==792
        152:  begin                 spi_cs <= 0;  end // Chip OFF.
      // Don't care about MOSI for all other states, but 0 is as fine as any:
        default: begin spi_mosi <= 0; end
      `endif
      endcase

    end // source_direct
  
    // Alternate byte colouring during valid byte display region:
    if ( hpos>=32 && 0==((hpos)&'b111) ) begin
      byte_alt <= ~byte_alt;
    end
  
  end

  wire blanking = ~visible;
  wire border_en = (hpos=='d0 || hpos=='d639 || vpos=='d0 || vpos=='d479);
  
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

  wire ram_bit = (vpos[1:0]==0) ? 1'b0 : data_buffer[119];
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

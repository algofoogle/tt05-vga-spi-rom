`default_nettype none
`timescale 1ns / 1ps

`include "helpers.v"


module vga_spi_rom(
  input               clk,
  input               reset,
  input wire          vga_mode, // 0=640x480@60Hz, 1=1440x900@60Hz
  // VGA outputs:
  output wire         hsync,  // Polarity matches whatever the selected 'vga_mode' needs.
  output wire         vsync,  // Polarity matches whatever the selected 'vga_mode' needs.
  output wire `RGB    rgb,
  // SPI ROM interface:
  output wire         spi_cs, //NOTE: Active HIGH. Most chips use active LOW (csb, cs_n, ss_n, whatever). Invert as needed in parent module.
  output wire         spi_sclk,
  // This is the generic SPI controller interface, to support both normal SPI (single) and QSPI.
  // For normal SPI, spi_dir0==0 (io0 is MOSI, an output; the rest are inputs (for safety) but unused).
  // For QSPI, spi_dir0 changes between 0 and 1 as required i.e. io[0] switches direction, while io[3:1] remain as inputs.
  input wire [3:0]    spi_in,   // "In" side of io0..3 -- NOTE: spi_in[1] is typically MISO.
  output wire         spi_out0, // "Out" side of io0 -- NOTE: spi_out0 is typically MOSI.
  output wire         spi_dir0  // Direction control for SPI io[0]. 0=Output, 1=Input
);

  localparam [9:0]    BUFFER_DEPTH      = 136;                            // Number of SPI data bits to read per line. Also sets size of our storage memory.
  localparam          BUFFER_ADDR_TOP   = $clog2(BUFFER_DEPTH)-1;         // Buffer's address MSB, i.e. index into buffer.
  localparam [9:0]    SPI_CMD_LEN       = 8;                              // Number of bits to send first as SPI command.
  localparam [9:0]    SPI_ADDR_LEN      = 24;                             // Number of address bits to send after SPI command.
  localparam [9:0]    PREAMBLE_LEN      = SPI_CMD_LEN + SPI_ADDR_LEN;     // Total length of CMD+ADDR bits, before chip will start producing output data.
  localparam [9:0]    STREAM_LEN        = PREAMBLE_LEN + BUFFER_DEPTH;    // Number of bits in our full SPI read stream.
  localparam [9:0]    STORED_MODE_HEAD  = 192;                            // When, in VGA line, to start the 'stored mode' sequence. (640-PREAMBLE_LEN) would run preamble (32bits, CMD[7:0] + ADDR[23:0]) to complete at end of 640w line.
  localparam [9:0]    STORED_MODE_TAIL  = STORED_MODE_HEAD + STREAM_LEN;  // When, in VGA line, to STOP the 'stored mode' sequence, to prevent buffer overrun.

  // Parameters for doing QSPI reads. Builds on SPI params above.
  localparam [9:0]    QSPI_NIBBLE_COUNT = 136;                            // 68 bytes.
  localparam [9:0]    QSPI_DUMMY_BITS   = 8;                              // Num extra SCLKs after SPI Quad Read command (6Bh) we wait before quad data starts streaming out.
  localparam [9:0]    QSPI_PREAMBLE_LEN = PREAMBLE_LEN + QSPI_DUMMY_BITS; // Expected to add up to 40 (cmd:8 addr:24 dummy:8); 8 more than single-SPI above.
  localparam [9:0]    QSPI_STREAM_LEN   = QSPI_PREAMBLE_LEN + QSPI_NIBBLE_COUNT; // Expected to add up to 176 (preamble:40 data:136).
  // Quad Output Fast Read Array (6Bh):
  // See https://github.com/algofoogle/journal/blob/master/0164-2023-10-23.md#sequence-for-quad-output-fast-read-array-6bh
  // for details of the sequence I plan on using.

  // --- VGA sync driver: ---
  wire [9:0] hpos, vpos;
  wire visible;
  wire hmax, vmax;
  vga_sync vga_sync(
    .clk      (clk),
    .reset    (reset),
    .mode     (vga_mode), // 0=640x480@60Hz, 1=1440x900@60Hz
    .o_hsync  (hsync),  // vga_sync module ensures polarity matches whatever the selected 'mode' needs.
    .o_vsync  (vsync),  // vga_sync module ensures polarity matches whatever the selected 'mode' needs.
    .o_hpos   (hpos),
    .o_vpos   (vpos),
    .o_hmax   (hmax),
    .o_vmax   (vmax),
    .o_visible(visible)
  );

  wire quad = vpos[8]; // For lines 256 and onwards, switch to running QSPI (Quad Read) test instead.

  // Inverted clk directly drives SPI SCLK at full speed, continuously:
  assign spi_sclk = ~clk; 
  // Why inverted? Because this allows us to set up MOSI on rising clk edge,
  // then it's stable by the spi_sclk would subsequently rise to clock that MOSI
  // data into the SPI chip.

  // Stored mode or direct mode?
  wire stored_mode = vpos[2]==0;
  // Even 4-line group: stored mode: read MISO to internal memory; deferred display.
  // Odd  4-line group: direct mode: read and display MISO data directly.

  // The 'memory' storing data read from SPI flash ROM, when in stored_mode:
  reg [BUFFER_DEPTH-1:0] data_buffer;

  // SPI states follow hpos, with an offset based on stored_mode...
  wire [9:0] state = 
    quad        ? hpos: // For now, in quad mode, EVERY line is the same (direct inputs to screen).
    stored_mode ? (hpos - STORED_MODE_HEAD):
                  hpos;

  // This screen-time range is when we store from MISO to buffer:
  wire store_data_region = (hpos >= STORED_MODE_HEAD+PREAMBLE_LEN && hpos < STORED_MODE_TAIL);
  //NOTE: Could/should we instead use 'state'?

  //NOTE: BEWARE: posedge of SPI_SCLK (not clk) here, because this is where MISO output is stable...
  always @(posedge spi_sclk) begin
    if (quad) begin
      //TODO: During the QSPI test we WILL do things a little differently, but
      // not yet... TO BE IMPLEMENTED!
    end else if (!quad) begin
      if (stored_mode) begin
        if (store_data_region) begin
          // Bits are streaming out via MISO (SPI io[1]), so shift them into data_buffer:
          data_buffer <= {data_buffer[BUFFER_DEPTH-2:0], spi_in[1]};
        end
      end
    end
  end

  // Chip is ON for the whole duration of our SPI read stream:
  assign spi_cs =
    quad  ? (state < QSPI_STREAM_LEN):
            (state < STREAM_LEN);

  // In quad mode, io[0] dir changes. In regular mode, it's always *considered*
  // to be an output, but it actually only needs to drive an output within the
  // first 32 clocks. This is true for both quad mode and regular mode, so we
  // just keep the logic the same between both modes...
  //NOTE: This dir is an 'oeb' (/OE) so 0=Output, 1=Input.
  assign spi_dir0 = (state >= 33); // <32, dir is 0 (OUTPUT). >=32, dir is 1 (INPUT).
  //NOTE: io0 can switch to INPUT probably in any cycle from 32..39, since it is
  // otherwise unused during this time (i.e. dummy bytes) and there is no
  // contention. I chose 33 for now to ensure the last address bit's hold
  // time is clear, but it probably should just be >= 32 instead.

    // quad ?  (state >= 32):  // From clock 32, io0 dir is 1 (INPUT). Otherwise, it's 0 (OUTPUT) i.e. MOSI sending out CMD:8+ADDR:24.
    //         1'b0;           // When not in quad mode, io0 is always MOSI; hence OUTPUT.
  // SPI io[3:1] are always considered inputs.

  wire [7:0] spi_cmd = quad ? 8'h6B : 8'h03;

  // This is a simple way to work out what data to present at MOSI during the
  // SPI preamble:
  assign spi_out0 =
    quad ? (
      // In quad mode, we read 68 bytes per line (64-byte aligned):
      (state<8)                 ? spi_cmd[7-state]: // CMD[7:0]
      (state>=19 && state<=25)  ? vpos[28-state]:   // ADDR[12:6] is vpos[9:3]
                                  1'b0              // 0 for all other preamble bits and beyond.
    ) : (
      // In regular mode, we read 17 bytes per line (16-byte aligned):
      (state<8)                 ? spi_cmd[7-state]: // CMD[7:0]
      (state>=21 && state<=27)  ? vpos[30-state]:   // ADDR[10:4] is vpos[9:3]
                                  1'b0              // 0 for all other preamble bits and beyond.
    );



  // The above combo logic for spi_cs and MOSI (spi_out0) gives us the following output
  // for each 'state':
  //
  // | state       | spi_cs   | MOSI     | note                                |
  // |------------:|---------:|---------:|:------------------------------------|
  // | (n)         | 0        | 0        | (any state not otherwise covered)   |
  // |  0          | 1        | CMD[7]   | CMD[7]; chip ON                     |
  // |  1          | 1        | CMD[6]   | CMD[6]                              |
  // |  2          | 1        | CMD[5]   | CMD[5]                              |
  // |  3          | 1        | CMD[4]   | CMD[4]                              |
  // |  4          | 1        | CMD[3]   | CMD[3]                              |
  // |  5          | 1        | CMD[2]   | CMD[2]                              |
  // |  6          | 1        | CMD[1]   | CMD[1]                              |
  // |  7          | 1        | CMD[0]   | CMD[0] => CMD 03h or 6Bh loaded.    |
  // |  8          | 1        | 0        | ADDR[23]                            |
  // |  9          | 1        | 0        | ADDR[22]                            |
  // | 10          | 1        | 0        | ADDR[21]                            |
  // | 11          | 1        | 0        | ADDR[20]                            |
  // | 12          | 1        | 0        | ADDR[19]                            |
  // | 13          | 1        | 0        | ADDR[18]                            |
  // | 14          | 1        | 0        | ADDR[17]                            |
  // | 15          | 1        | 0        | ADDR[16]                            |
  // | 16          | 1        | 0        | ADDR[15]                            |
  // | 17          | 1        | 0        | ADDR[14]                            |
  // | 18          | 1        | 0        | ADDR[13]                            |
  // | 19          | 1        | 0        | ADDR[12]                            |
  // | 20          | 1        | 0        | ADDR[11]                            |
  // | 21          | 1        | vpos[9]  | ADDR[10]                            |
  // | 22          | 1        | vpos[8]  | ADDR[9]                             |
  // | 23          | 1        | vpos[7]  | ADDR[8]                             |
  // | 24          | 1        | vpos[6]  | ADDR[7]                             |
  // | 25          | 1        | vpos[5]  | ADDR[6]                             |
  // | 26          | 1        | vpos[4]  | ADDR[5]                             |
  // | 27          | 1        | vpos[3]  | ADDR[4]                             |
  // | 28          | 1        | 0        | ADDR[3]                             |
  // | 29          | 1        | 0        | ADDR[2]                             |
  // | 30          | 1        | 0        | ADDR[1]                             |
  // | 31          | 1        | 0        | ADDR[0]                             |
  // | THEN IF QUAD:                                                           |
  // | **32..39**  | 1        | Z        | 8 dummy SCLKs                       |
  // | 40..N-1     | 1        | Z        | Reading nibbles in via io[3:0]      |
  // | N           | 0        | 0        | Chip OFF                            |
  // | ELSE IF SINGLE:                                                         |
  // | 32..N-1     | 1        | Z        | Reading bits in via MISO (io[1])    |
  // | N           | 0        | 0        | Chip OFF                            |
  // ...where N is either QSPI_STREAM_LEN or just STREAM_LEN.

  // On screen, we highlight where byte boundaries would be, by alternating the
  // background colour every 8 horizontal pixels. 'Even bytes' are those where
  // hpos[3]==0; 'odd' when hpos[3]==1.
  wire odd_byte = hpos[3];

  // Work out the bit index in the data_buffer shift reg for retrieval of
  // each pixel, as relative to hpos and where we want those bits on screen:
  wire [9:0] data_index_base = BUFFER_DEPTH+PREAMBLE_LEN-10'd1 - hpos;
  wire [BUFFER_ADDR_TOP:0] data_index = data_index_base[BUFFER_ADDR_TOP:0]; // Enough bits to cover BUFFER_DEPTH.
  // Data comes from...
  wire mask_stored = stored_mode && (hpos < PREAMBLE_LEN || hpos >= STREAM_LEN); //TODO: Make optional.
  wire data =
    mask_stored ? 1'b0:                     // ...nowhere, outside paint range.
    stored_mode ? data_buffer[data_index]:  // ...memory, in stored mode.
                  spi_in[1];                // ...chip, in direct mode.

  // In quad mode, spi_in[2:0] drive base BGR color, while io[3] shifts for intensity:
  wire `RGB quad_color =
    // Blue             // Green          // Red
    ({{1'b0,spi_in[2]}, {1'b0,spi_in[1]}, {1'b0,spi_in[0]} } << spi_in[3]) | // io[3] shifts for intensity
    ({{1'b0,spi_in[3]}, {1'b0,spi_in[3]}, {1'b0,spi_in[3]} }); // io[3] then also adds for extra intensity

  wire `RGB pixel_color =
    // Force green pixels during MOSI being driven high:
    (spi_out0 && 0==spi_dir0) ? 6'b00_11_00:
    quad                      ? quad_color:
    // Else, B=/CS, G=data, R=odd/even byte.
                                { {2{spi_cs}}, {2{data}}, {2{~odd_byte}} };

  // Dividing lines are blacked out, i.e. first line of each address line pair,
  // because they contain buffer junk, but also to make it easier to see pairs:
  wire dividing_line = vpos[2:0]==0;

  // Decide what the final RGB pixel output colour is:
  assign rgb =
    (!visible)      ? 6'b00_00_00: // Black for blanking.
    (dividing_line) ? 6'b00_00_00: // Black for dividing lines.
                      pixel_color;
  
endmodule

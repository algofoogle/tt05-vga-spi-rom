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
  output wire         spi_cs, //NOTE: Active HIGH. Most chips use active LOW (csb, cs_n, ss_n, whatever). Invert as needed in parent module.
  output wire         spi_sclk,
  output wire         spi_mosi,
  input  wire         spi_miso
);

  localparam [9:0]    BUFFER_DEPTH      = 136;                            // Number of SPI data bits to read per line. Also sets size of our storage memory.
  localparam          BUFFER_ADDR_TOP   = $clog2(BUFFER_DEPTH)-1;         // Buffer's address MSB, i.e. index into buffer.
  localparam [9:0]    SPI_CMD_LEN       = 8;                              // Number of bits to send first as SPI command.
  localparam [9:0]    SPI_ADDR_LEN      = 24;                             // Number of address bits to send after SPI command.
  localparam [9:0]    PREAMBLE_LEN      = SPI_CMD_LEN + SPI_ADDR_LEN;     // Total length of CMD+ADDR bits, before chip will start producing output data.
  localparam [9:0]    STREAM_LEN        = PREAMBLE_LEN + BUFFER_DEPTH;    // Number of bits in our full SPI read stream.
  localparam [9:0]    STORED_MODE_HEAD  = 192;                            // When, in VGA line, to start the 'stored mode' sequence. (640-PREAMBLE_LEN) would run preamble (32bits, CMD[7:0] + ADDR[23:0]) to complete at end of 640w line.
  localparam [9:0]    STORED_MODE_TAIL  = STORED_MODE_HEAD + STREAM_LEN;  // When, in VGA line, to STOP the 'stored mode' sequence, to prevent buffer overrun.

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
    stored_mode ? (hpos - STORED_MODE_HEAD):
                  hpos;

  // This screen-time range is when we store from MISO to buffer:
  wire store_data_region = (hpos >= STORED_MODE_HEAD+PREAMBLE_LEN && hpos < STORED_MODE_TAIL);
  //NOTE: Could/should we instead use 'state'?

  //NOTE: BEWARE: posedge of SPI_SCLK (not clk) here, because this is where MISO output is stable...
  always @(posedge spi_sclk) begin
    if (stored_mode) begin
      if (store_data_region) begin
        // Bits are streaming out via MISO, so shift them into data_buffer:
        data_buffer <= {data_buffer[BUFFER_DEPTH-2:0], spi_miso};
      end
    end
  end

  // Chip is ON for the whole duration of our SPI read stream:
  assign spi_cs = state < STREAM_LEN;

  // This is a simple way to work out what data to present at MOSI during the
  // SPI preamble:
  assign spi_mosi =
    (state== 6 || state== 7)  ? 1'b1:           // CMD[1:0] is 'b11.
    (state>=21 && state<=27)  ? vpos[30-state]: // ADDR[10:4] is vpos[9:3]
                                1'b0;           // 0 for all other preamble bits
                                                // and beyond.
  // The above combo logic for spi_cs and spi_mosi gives us the following output
  // for each 'state':
  //
  // | state    | spi_cs   | spi_mosi | note                              |
  // |---------:|---------:|---------:|:----------------------------------|
  // | (n)      | 0        | 0        | (any state not otherwise covered) |
  // |  0       | 1        | 0        | CMD[7]; chip ON                   |
  // |  1       | 1        | 0        | CMD[6]                            |
  // |  2       | 1        | 0        | CMD[5]                            |
  // |  3       | 1        | 0        | CMD[4]                            |
  // |  4       | 1        | 0        | CMD[3]                            |
  // |  5       | 1        | 0        | CMD[2]                            |
  // |  6       | 1        | 1        | CMD[1]                            |
  // |  7       | 1        | 1        | CMD[0] => CMD 03h (READ) loaded.  |
  // |  8       | 1        | 0        | ADDR[23]                          |
  // |  9       | 1        | 0        | ADDR[22]                          |
  // | 10       | 1        | 0        | ADDR[21]                          |
  // | 11       | 1        | 0        | ADDR[20]                          |
  // | 12       | 1        | 0        | ADDR[19]                          |
  // | 13       | 1        | 0        | ADDR[18]                          |
  // | 14       | 1        | 0        | ADDR[17]                          |
  // | 15       | 1        | 0        | ADDR[16]                          |
  // | 16       | 1        | 0        | ADDR[15]                          |
  // | 17       | 1        | 0        | ADDR[14]                          |
  // | 18       | 1        | 0        | ADDR[13]                          |
  // | 19       | 1        | 0        | ADDR[12]                          |
  // | 20       | 1        | 0        | ADDR[11]                          |
  // | 21       | 1        | vpos[9]  | ADDR[10]                          |
  // | 22       | 1        | vpos[8]  | ADDR[9]                           |
  // | 23       | 1        | vpos[7]  | ADDR[8]                           |
  // | 24       | 1        | vpos[6]  | ADDR[7]                           |
  // | 25       | 1        | vpos[5]  | ADDR[6]                           |
  // | 26       | 1        | vpos[4]  | ADDR[5]                           |
  // | 27       | 1        | vpos[3]  | ADDR[4]                           |
  // | 28       | 1        | 0        | ADDR[3]                           |
  // | 29       | 1        | 0        | ADDR[2]                           |
  // | 30       | 1        | 0        | ADDR[1]                           |
  // | 31       | 1        | 0        | ADDR[0]                           |
  // | 32..159  | 1        | 0        | MOSI=dummy, MISO=read bit         |
  // | 160      | 0        | 0        | Chip OFF                          |

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
    mask_stored ? 1'b0:                     // ...nowhere outside paint range.
    stored_mode ? data_buffer[data_index]:  // ...memory, in stored mode.
                  spi_miso;                 // ...chip, in direct mode.

  wire `RGB pixel_color =
    // Force green pixels during MOSI high:
    spi_mosi  ? 9'b000_111_000:
    // Else, B=/CS, G=data, R=odd/even byte.
                { {3{spi_cs}}, {3{data}}, {3{~odd_byte}} };

  // Dividing lines are blacked out, i.e. first line of each address line pair,
  // because they contain buffer junk, but also to make it easier to see pairs:
  wire dividing_line = vpos[2:0]==0;

  // Decide what the final RGB pixel output colour is:
  assign rgb =
    (!visible)      ? 9'b000_000_000: // Black for blanking.
    (dividing_line) ? 9'b000_000_000: // Black for dividing lines.
                      pixel_color;
  
endmodule

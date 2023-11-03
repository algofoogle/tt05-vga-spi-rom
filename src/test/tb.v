`default_nettype none
`timescale 1ns/1ps

module tb;

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
    end

    // --- Inputs controlled by test ---

    reg clk;
    reg rst_n;
    reg ena;
    reg [2:0] Test_in;

    // --- DUT's generic IOs from the TT wrapper ---
    wire [7:0] ui_in;       // Dedicated inputs
    wire [7:0] uo_out;      // Dedicated outputs
    wire [7:0] uio_in;      // IOs: Input path -- UNUSED in this design.
    wire [7:0] uio_out;     // IOs: Output path
    wire [7:0] uio_oe;      // IOs: Enable path (active high: 0=input, 1=output) -- ALWAYS all 1 (all outputs) in this design.

    // --- Mapping DUT's generic IOs to meaningful signal names for our tests ---

    // SPI connected to our spiflash sim module:
    wire spi_cs_n = uio_out[0];
    wire spi_sclk = uio_out[3];
    wire spi_mosi = uio_out[1];
    wire spi_miso;
    assign uio_in[2] = spi_miso;

    wire vsync_n = uo_out[3];
    wire hsync_n = uo_out[7];

    // Each of the 3-bit R, G, and B outputs:
    wire [1:0] r = {uo_out[0], uo_out[4]};
    wire [1:0] g = {uo_out[1], uo_out[5]};
    wire [1:0] b = {uo_out[2], uo_out[6]};

    // Combined RGB222 output (BGR order):
    wire [5:0] rgb = {b,g,r};

    // Simple gate delay test:
    assign ui_in[7:5] = Test_in;
    wire Test_out = uio_out[4];

    // This is the TT05-wrapped main design that we're testing:
    tt_um_algofoogle_vga_spi_rom uut (
        .ui_in      (ui_in),    // Dedicated inputs
        .uo_out     (uo_out),   // Dedicated outputs
        .uio_in     (uio_in),   // IOs: Input path -- UNUSED in this design.
        .uio_out    (uio_out),  // IOs: Output path
        .uio_oe     (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
        .ena        (ena),      // will go high when the design is enabled
        .clk        (clk),      // clock
        .rst_n      (rst_n)     // reset_n - low to reset
    );

    // This simulates the SPI flash ROM that we attach to our ASIC:
    spiflash #(
        // .verbose(1), // Spew SPI debug info.
        //SMELL: Working directory for tests is src/, not src/test/:
        .FILENAME("test/test_rom.hex")
    ) spiflash (
        .csb(spi_cs_n),
        .clk(spi_sclk),
        .io0(spi_mosi),
        .io1(spi_miso)
    );


endmodule

`default_nettype none
`timescale 1ns/1ps

module tb (
    input clk,
    input reset,
    // SPI flash ROM interface:
    output spi_cs_n, spi_sclk, spi_mosi,
    input spi_miso,
    // VGA output:
    output hsync_n, vsync_n,
    output [2:0] r, g, b
);

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
    end

    wire spi_cs;
    assign spi_cs_n = ~spi_cs;

    // This is the main design that we're testing:
    vga_spi_rom uut(
        // --- Inputs: ---
        .clk        (clk),
        .reset      (reset),
        // --- Outputs: ---
        .hsync_n    (hsync_n),
        .vsync_n    (vsync_n),
        .rgb        ({b,g,r}),
        // --- SPI ROM interface: ---
        .spi_cs     (spi_cs),
        .spi_sclk   (spi_sclk),
        .spi_mosi   (spi_mosi),
        .spi_miso   (spi_miso)
    );

endmodule

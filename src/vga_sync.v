`default_nettype none
`timescale 1ns / 1ps

module vga_sync #(
  // 1280x720p60 resolution:
  // *** POS sync polarity
  // *** WORKS ON MY FHD Acer monitor
  // *** WORKS ON MY QHD ViewSonic monitor
  // *** WORKS on my Vention VGA-to-HDMI adapter
  // -          Base:       Div-3     Round
  // -  Clock:  74.25MHz    24.75MHz
  // -  FPS:    60Hz                  Effective: 24,750,000/367/1125=59.946Hz
  // -  HTotal: 1650        550       550
  // -  HRes:   1280        426.667   426 (round down to prevent overshoot?)
  // -  HFront: 110         36.667    37 (or try rounding up to 38?)
  // -  HSync:  40          13.333    13 (or try rounding up to 14?)
  // -  HBack:  220         73.333    73 (or try rounding up to 74?)
  // -  HBLANK: 370         123.333   123 (x3=369)
  // -  VTotal: 750
  // -  VRes:   720
  // -  VFront: 5
  // -  VSync:  5
  // -  VBack:  20
  // -  VBLANK: 30

  // // 550 clocks wide:
  // parameter H_VIEW        = 426,   // Visible area comes first...
  // parameter H_FRONT       =  38,   // ...then HBLANK starts with H_FRONT (RHS border)...
  // parameter H_SYNC        =  13,   // ...then sync pulse starts...
  // parameter H_BACK        =  73,   // ...then remainder of HBLANK (LHS border).
  // parameter H_MAX         = H_VIEW + H_FRONT + H_SYNC + H_BACK - 1,
  // parameter H_SYNC_START  = H_VIEW + H_FRONT,
  // parameter H_SYNC_END    = H_SYNC_START + H_SYNC,
  // // 750 lines tall:
  // parameter V_VIEW        = 720,
  // parameter V_FRONT       =   5,
  // parameter V_SYNC        =   5,
  // parameter V_BACK        =  20,
  // parameter V_MAX         = V_VIEW + V_FRONT + V_SYNC + V_BACK - 1,
  // parameter V_SYNC_START  = V_VIEW + V_FRONT,
  // parameter V_SYNC_END    = V_SYNC_START + V_SYNC

  // Trying 1920x1080p60 using CVT timing (28.833MHz PLL):
  // 550 clocks wide:
  parameter H_VIEW        = 320,   // Visible area comes first...
  parameter H_FRONT       =  21,   // ...then HBLANK starts with H_FRONT (RHS border)...
  parameter H_SYNC        =  34,   // ...then sync pulse starts...
  parameter H_BACK        =  55,   // ...then remainder of HBLANK (LHS border).
  parameter H_MAX         = H_VIEW + H_FRONT + H_SYNC + H_BACK - 1,
  parameter H_SYNC_START  = H_VIEW + H_FRONT,
  parameter H_SYNC_END    = H_SYNC_START + H_SYNC,
  // 750 lines tall:
  parameter V_VIEW        = 1080,
  parameter V_FRONT       =   3,
  parameter V_SYNC        =   5,
  parameter V_BACK        =  32,
  parameter V_MAX         = V_VIEW + V_FRONT + V_SYNC + V_BACK - 1,
  parameter V_SYNC_START  = V_VIEW + V_FRONT,
  parameter V_SYNC_END    = V_SYNC_START + V_SYNC

  // 1920x1080p60 resolution:
  // -          Base:       Div-6     Round
  // -  Clock:  148.5MHz    24.75MHz
  // -  FPS:    60Hz                  Effective: 24,750,000/367/1125=59.946Hz
  // -  HTotal: 2200        366.667   367
  // -  HRes:   1920        320
  // -  HFront: 88          14.667    15
  // -  HSync:  44          7.333     7
  // -  HBack:  148         24.667    25
  // -  (HBLANK: 280)       46.667    47
  // -  VTotal: 1125
  // -  VRes:   1080
  // -  VFront: 4
  // -  VSync:  5
  // -  VBack:  36
  // -  (VBLANK: 45)
  // 
  // 367 clocks wide, TOTAL SUM:
  // // DOESN'T WORK ON ACER MONITOR:
  // parameter H_VIEW        = 320,   // Visible area comes first...
  // parameter H_FRONT       =  15,   // ...then HBLANK starts with H_FRONT (RHS border)...
  // parameter H_SYNC        =   8, // 7 no good either.   // ...then sync pulse starts...
  // parameter H_BACK        =  25,   // ...then remainder of HBLANK (LHS border).
  // parameter H_MAX         = H_VIEW + H_FRONT + H_SYNC + H_BACK - 1,
  // parameter H_SYNC_START  = H_VIEW + H_FRONT,
  // parameter H_SYNC_END    = H_SYNC_START + H_SYNC,
  // // 1125 lines tall, TOTAL SUM:
  // parameter V_VIEW        = 1080,
  // parameter V_FRONT       =    4,
  // parameter V_SYNC        =    5,
  // parameter V_BACK        =   36,
  // parameter V_MAX         = V_VIEW + V_FRONT + V_SYNC + V_BACK - 1,
  // parameter V_SYNC_START  = V_VIEW + V_FRONT,
  // parameter V_SYNC_END    = V_SYNC_START + V_SYNC

  // // 1920x1080p30
  // // DOESN'T WORK ON ACER MONITOR:
  // parameter H_VIEW        = 640,   // Visible area comes first...
  // parameter H_FRONT       =  29,   // ...then HBLANK starts with H_FRONT (RHS border)...
  // parameter H_SYNC        =  15,   // ...then sync pulse starts...
  // parameter H_BACK        =  49,   // ...then remainder of HBLANK (LHS border).
  // parameter H_MAX         = H_VIEW + H_FRONT + H_SYNC + H_BACK - 1,
  // parameter H_SYNC_START  = H_VIEW + H_FRONT,
  // parameter H_SYNC_END    = H_SYNC_START + H_SYNC,
  // // 1125 lines tall, TOTAL SUM:
  // parameter V_VIEW        = 1080,
  // parameter V_FRONT       =    4,
  // parameter V_SYNC        =    5,
  // parameter V_BACK        =   36,
  // parameter V_MAX         = V_VIEW + V_FRONT + V_SYNC + V_BACK - 1,
  // parameter V_SYNC_START  = V_VIEW + V_FRONT,
  // parameter V_SYNC_END    = V_SYNC_START + V_SYNC

  // parameter H_VIEW        = 240,   // Visible area comes first...
  // parameter H_FRONT       =  11,   // ...then HBLANK starts with H_FRONT (RHS border)...
  // parameter H_SYNC        =   6,   // ...then sync pulse starts...
  // parameter H_BACK        =  18,   // ...then remainder of HBLANK (LHS border).
  // parameter H_MAX         = H_VIEW + H_FRONT + H_SYNC + H_BACK - 1,
  // parameter H_SYNC_START  = H_VIEW + H_FRONT,
  // parameter H_SYNC_END    = H_SYNC_START + H_SYNC,
  // // 1125 lines tall:
  // parameter V_VIEW        = 1125,
  // parameter V_FRONT       =    4,
  // parameter V_SYNC        =    5,
  // parameter V_BACK        =   36,
  // parameter V_MAX         = V_VIEW + V_FRONT + V_SYNC + V_BACK - 1,
  // parameter V_SYNC_START  = V_VIEW + V_FRONT,
  // parameter V_SYNC_END    = V_SYNC_START + V_SYNC


  // 1920x1080p30:
  // Doesn't work on Acer FHD, and not on Vention either? Not tested others yet.
  // -          Base:       Div-3     Round
  // -  Clock:  74.25MHz    24.75MHz
  // -  FPS:    60Hz                  Effective: 24,750,000/367/1125=59.946Hz
  // -  HTotal: 2200        733.333   733 (2199, or try for 734: 2202)
  // -  HRes:   1920        640
  // -  HFront: 88          29.333    29
  // -  HSync:  44          14.666    15
  // -  HBack:  148         49.333    49
  // -  (HBLANK: 280)       93.333    93
  // -  VTotal: 1125
  // -  VRes:   1080
  // -  VFront: 4
  // -  VSync:  5
  // -  VBack:  36
  // -  (VBLANK: 45)
  // 
  // parameter H_VIEW        = 640,   // Visible area comes first...
  // parameter H_FRONT       =  29,   // ...then HBLANK starts with H_FRONT (RHS border)...
  // parameter H_SYNC        =  14,   // ...then sync pulse starts...
  // parameter H_BACK        =  49,   // ...then remainder of HBLANK (LHS border).
  // parameter H_MAX         = H_VIEW + H_FRONT + H_SYNC + H_BACK - 1,
  // parameter H_SYNC_START  = H_VIEW + H_FRONT,
  // parameter H_SYNC_END    = H_SYNC_START + H_SYNC,
  // // 1125 lines tall:
  // parameter V_VIEW        = 1125,
  // parameter V_FRONT       =    4,
  // parameter V_SYNC        =    5,
  // parameter V_BACK        =   36,
  // parameter V_MAX         = V_VIEW + V_FRONT + V_SYNC + V_BACK - 1,
  // parameter V_SYNC_START  = V_VIEW + V_FRONT,
  // parameter V_SYNC_END    = V_SYNC_START + V_SYNC

  // // Overall timing for true VGA 25.175MHz clock: 25,175,000 / 800 / 525 = 59.94Hz
  // // or for 25.0MHz clock: 59.52Hz
  // // Try pushing these timings around and see what happens.
) (
  // Inputs:
  input wire          clk,
  input wire          reset,
  // Outputs:
  output reg          hsync,  //NOTE: POSITIVE polarity. Would normally be inverted (active LOW) for VGA display.
  output reg          vsync,  //NOTE: POSITIVE polarity. Would normally be inverted (active LOW) for VGA display.
  output reg [9:0]    hpos,
  output reg [9:0]    vpos,
  output wire         hmax,
  output wire         vmax,
  output wire         visible
);


  //TODO: Reduce equality checks to just test the bits that matter,
  // because we don't care about values ABOVE these.
  // Might also be able to do similar with comparisons.
  //TODO: Consider making 'visible' a reg insted of combo.

  assign hmax = (hpos == H_MAX);
  assign vmax = (vpos == V_MAX);
  assign visible = (hpos<H_VIEW && vpos<V_VIEW);

  // Horizontal tracing:
  always @(posedge clk) begin
          if (reset)                      hpos <= 0;
    else  if (hmax)                       hpos <= 0;
    else                                  hpos <= hpos + 1'b1;
  end

  // Vertical tracing:
  always @(posedge clk) begin
          if (reset)                      vpos <= 0;
    else  if (hmax)                       vpos <= (vmax) ? 1'b0 : vpos + 1'b1;
  end

  // HSYNC:
  always @(posedge clk) begin
          if (hpos==H_SYNC_END || reset)  hsync <= 0;
    else  if (hpos==H_SYNC_START)         hsync <= 1;
  end

  // VSYNC:
  always @(posedge clk) begin
          if (vpos==V_SYNC_END || reset)  vsync <= 0;
    else  if (vpos==V_SYNC_START)         vsync <= 1;
  end
endmodule

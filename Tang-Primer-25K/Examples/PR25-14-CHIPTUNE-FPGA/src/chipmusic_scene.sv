// PR25-14: 160x90 indexed 64-color ROM, scaled 4x into 640x360
// centered in a 720x480 HDMI picture. No SDRAM required.
// Two text ROM files are reconstructed by Build_Chiptune.ps1.
module chipmusic_scene (
  input logic clk,
  input logic [10:0] next_x,
  input logic [9:0] next_y,
  input logic beat_toggle,
  output logic [23:0] rgb
);
  reg [7:0] image_rom [0:14399] /* synthesis syn_romstyle = "block_rom" */;
  reg [23:0] palette [0:63];
  initial begin
    $readmemh("scene_pixels.mem",image_rom);
    $readmemh("scene_palette.mem",palette);
  end

  // The pixel clock domain samples the beat only through 2 FF stages.
  logic beat_s1 = 1'b0;
  logic beat_s2 = 1'b0;
  logic [7:0] beat_count = '0;
  logic [8:0] frame_count = '0;
  always_ff @(posedge clk) begin
    beat_s1 <= beat_toggle;
    beat_s2 <= beat_s1;
    if (beat_s1 ^ beat_s2)
      beat_count <= beat_count + 8'd1;
    if (next_x == 0 && next_y == 0)
      frame_count <= frame_count + 9'd1;
  end

  wire inside = (next_x >= 11'd40) && (next_x < 11'd680) &&
                (next_y >= 10'd60) && (next_y < 10'd420);
  wire [7:0] sx = (next_x - 11'd40) >> 2;
  wire [6:0] sy = (next_y - 10'd60) >> 2;
  wire [13:0] addr = ({7'd0,sy} << 7) + ({7'd0,sy} << 5) + sx;

  logic [7:0] rom_index;
  logic [7:0] sx_q;
  logic [6:0] sy_q;
  logic inside_q;
  always_ff @(posedge clk) begin
    rom_index <= image_rom[addr];
    inside_q <= inside;
    sx_q <= sx;
    sy_q <= sy;
  end

  // Equalizer animation overlaid on the central CRT. It is fed by the
  // chiptune sequencer's beat toggle (safely synchronized), not by a movie.
  logic [3:0] motion;
  logic [3:0] amplitude;
  always_comb begin
    rgb = 24'h02030b;
    if (inside_q)
      rgb = palette[rom_index[5:0]];
    motion = 4'(sx_q[4:1] + frame_count[4:2] + beat_count[3:0]);
    amplitude = 4'(3 + motion[2:0]);
    if (inside_q && sx_q >= 8'd65 && sx_q < 8'd99 &&
        sy_q >= 7'd39 && sy_q < 7'd48) begin
      if ((sy_q >= (7'd48 - amplitude)) && (sx_q[1:0] != 2'd3)) begin
        if (sx_q < 8'd77) rgb = 24'h1cffe2;
        else if (sx_q < 8'd88) rgb = 24'hf9db42;
        else rgb = 24'hfa48c9;
      end else begin
        rgb = 24'h0b1846;
      end
    end
    // Two tiny twinkling pixels to show motion outside the screen itself.
    if (inside_q && frame_count[4] && sx_q == 8'd120 && sy_q == 7'd11)
      rgb = 24'hfef3a4;
    if (inside_q && frame_count[5] && sx_q == 8'd21 && sy_q == 7'd25)
      rgb = 24'hffeaa0;
  end
endmodule

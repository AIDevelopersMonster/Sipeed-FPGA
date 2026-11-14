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
  // Eight exact 2048 x 8 (16-Kbit) block-ROM banks (no LUT bitmap).
  // SUG949: syn_romstyle and synchronous read for Gowin pROM inference.
  reg [7:0] image_bank0 [0:2047] /* synthesis syn_romstyle = "block_rom" */;
  reg [7:0] image_bank1 [0:2047] /* synthesis syn_romstyle = "block_rom" */;
  reg [7:0] image_bank2 [0:2047] /* synthesis syn_romstyle = "block_rom" */;
  reg [7:0] image_bank3 [0:2047] /* synthesis syn_romstyle = "block_rom" */;
  reg [7:0] image_bank4 [0:2047] /* synthesis syn_romstyle = "block_rom" */;
  reg [7:0] image_bank5 [0:2047] /* synthesis syn_romstyle = "block_rom" */;
  reg [7:0] image_bank6 [0:2047] /* synthesis syn_romstyle = "block_rom" */;
  reg [7:0] image_bank7 [0:2047] /* synthesis syn_romstyle = "block_rom" */;
  reg [23:0] palette [0:63];
  initial begin
    $readmemh("scene_bank0.mem",image_bank0);
    $readmemh("scene_bank1.mem",image_bank1);
    $readmemh("scene_bank2.mem",image_bank2);
    $readmemh("scene_bank3.mem",image_bank3);
    $readmemh("scene_bank4.mem",image_bank4);
    $readmemh("scene_bank5.mem",image_bank5);
    $readmemh("scene_bank6.mem",image_bank6);
    $readmemh("scene_bank7.mem",image_bank7);
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

  wire visible_region = (next_x >= 11'd40) && (next_x < 11'd680) &&
                (next_y >= 10'd60) && (next_y < 10'd420);
  wire [7:0] sx = (next_x - 11'd40) >> 2;
  wire [6:0] sy = (next_y - 10'd60) >> 2;
  wire [13:0] addr = ({7'd0,sy} << 7) + ({7'd0,sy} << 5) + sx;

  // Each bank is read synchronously in parallel; bank select is delayed
  // by the SAME one clock as the data. Therefore pixel latency remains
  // identical to PR25-14 original one-cycle ROM read.
  logic [2:0] bank_q;
  logic [7:0] bank_data0;
  logic [7:0] bank_data1;
  logic [7:0] bank_data2;
  logic [7:0] bank_data3;
  logic [7:0] bank_data4;
  logic [7:0] bank_data5;
  logic [7:0] bank_data6;
  logic [7:0] bank_data7;
  logic [7:0] rom_index;
  always_comb begin
    case (bank_q)
      3'd0: rom_index = bank_data0;
      3'd1: rom_index = bank_data1;
      3'd2: rom_index = bank_data2;
      3'd3: rom_index = bank_data3;
      3'd4: rom_index = bank_data4;
      3'd5: rom_index = bank_data5;
      3'd6: rom_index = bank_data6;
      3'd7: rom_index = bank_data7;
      default: rom_index = 8'd0;
    endcase
  end
  logic [7:0] sx_q;
  logic [6:0] sy_q;
  logic inside_q;
  always_ff @(posedge clk) begin
    bank_data0 <= image_bank0[addr[10:0]];
    bank_data1 <= image_bank1[addr[10:0]];
    bank_data2 <= image_bank2[addr[10:0]];
    bank_data3 <= image_bank3[addr[10:0]];
    bank_data4 <= image_bank4[addr[10:0]];
    bank_data5 <= image_bank5[addr[10:0]];
    bank_data6 <= image_bank6[addr[10:0]];
    bank_data7 <= image_bank7[addr[10:0]];
    bank_q <= addr[13:11];
    inside_q <= visible_region;
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

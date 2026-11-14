// PR25-14: original simple three-voice chiptune synthesized in FPGA.
// 2x square voices + bass triangle-like voice; 32-step repeating melody.
// No sample/MP3/WAV decoder, no MCU and no external memory.
module chipmusic_audio (
  input logic clk_audio,
  input logic reset,
  output logic [15:0] audio_l,
  output logic [15:0] audio_r,
  output logic beat_toggle
);
  logic [13:0] tick = '0;
  logic [4:0] step = '0;
  logic [23:0] phase_m = '0;
  logic [23:0] phase_a = '0;
  logic [23:0] phase_b = '0;

  // Phase increment = round(note_frequency*2^24/48000).
  function automatic logic [23:0] increment(input logic [3:0] note);
    case (note)
       4'd1: increment=24'd45722;  // C3
       4'd2: increment=24'd51322;  // D3
       4'd3: increment=24'd57607;  // E3
       4'd4: increment=24'd68506;  // G3
       4'd5: increment=24'd76896;  // A3
       4'd6: increment=24'd91445;  // C4
       4'd7: increment=24'd102643; // D4
       4'd8: increment=24'd115213; // E4
       4'd9: increment=24'd137012; // G4
      4'd10: increment=24'd153791; // A4
      4'd11: increment=24'd182890; // C5
      4'd12: increment=24'd205287; // D5
      4'd13: increment=24'd230426; // E5
      4'd14: increment=24'd274025; // G5
      4'd15: increment=24'd307582; // A5
       default: increment=24'd0;
    endcase
  endfunction

  // 32 eighth-note steps, roughly 120 BPM at 48 kHz.
  function automatic logic [3:0] melody(input logic [4:0] pos);
    case (pos)
       0:melody=10;  1:melody=11;  2:melody=13;  3:melody=11;
       4:melody=10;  5:melody=8;   6:melody=9;   7:melody=8;
       8:melody=11;  9:melody=12; 10:melody=13; 11:melody=14;
      12:melody=13; 13:melody=11; 14:melody=10; 15:melody=9;
      16:melody=10; 17:melody=11; 18:melody=13; 19:melody=15;
      20:melody=14; 21:melody=13; 22:melody=11; 23:melody=10;
      24:melody=8;  25:melody=9;  26:melody=10; 27:melody=11;
      28:melody=13; 29:melody=11; 30:melody=10; 31:melody=5;
    endcase
  endfunction
  logic [3:0] melody_note;
  logic [3:0] arp_note;
  logic [3:0] bass_note;
  always_comb begin
    melody_note = melody(step);
    case (step[1:0])
      2'd0: arp_note = 4'd8;
      2'd1: arp_note = 4'd11;
      2'd2: arp_note = 4'd13;
      default:arp_note = 4'd11;
    endcase
    if (step[4:3]==2'd0 || step[4:3]==2'd2)
      bass_note=4'd5; // A3
    else if (step[4:3]==2'd1)
      bass_note=4'd1; // C3
    else
      bass_note=4'd4; // G3
  end

  // Signed 16-bit PCM. No overflow: 5400+2000+2600 < 32767.
  logic signed [16:0] mix_l;
  logic signed [16:0] mix_r;
  logic signed [15:0] tone_m, tone_a, tone_b;
  always_comb begin
    tone_m = phase_m[23] ? 16'sd5400 : -16'sd5400;
    tone_a = phase_a[23] ? 16'sd2000 : -16'sd2000;
    // Triangular bass from top 8 phase bits (8-bit characteristic tone).
    if (phase_b[23])
      tone_b = 16'sd2600 - $signed({1'b0,phase_b[22:15],4'b0});
    else
      tone_b = -16'sd2600 + $signed({1'b0,phase_b[22:15],4'b0});
    mix_l = $signed(tone_m) + $signed(tone_a) + $signed(tone_b);
    mix_r = $signed(tone_m) - $signed(tone_a) + $signed(tone_b);
  end
  always_ff @(posedge clk_audio) begin
    if (reset) begin
      tick <= '0;
      step <= '0;
      phase_m <= '0;
      phase_a <= '0;
      phase_b <= '0;
      beat_toggle <= 1'b0;
      audio_l <= 16'd0;
      audio_r <= 16'd0;
    end else begin
      if (tick == 14'd11999) begin
        tick <= '0;
        step <= step + 5'd1;
        beat_toggle <= ~beat_toggle;
        phase_m <= '0; // crisp retrigger on 8-bit sequencer steps
      end else begin
        tick <= tick + 14'd1;
        phase_m <= phase_m + increment(melody_note);
      end
      phase_a <= phase_a + increment(arp_note);
      phase_b <= phase_b + increment(bass_note);
      audio_l <= mix_l[15:0];
      audio_r <= mix_r[15:0];
    end
  end
endmodule

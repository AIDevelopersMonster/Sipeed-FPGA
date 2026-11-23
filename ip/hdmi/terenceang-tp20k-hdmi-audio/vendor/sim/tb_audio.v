`timescale 1ns/1ps
// Pixel-domain test of top.v's audio + video path (tone_1k -> hdmi_tx), decoded like a sink:
// finds data islands, TERC4-decodes packets, checks BCH, extracts Audio Sample Packets
// and checks they carry a 1 kHz sine at 48 kHz; checks ACR (N=6144, CTS=27000), the
// AVI + Audio InfoFrames, and one line of colour bars.
module tb_audio;
    `include "sim/include/hdmi_ref.vh"

    reg clk = 0;
    always #18.519 clk = ~clk;          // 27 MHz pixel clock
    reg rst_n = 0;

    // ---- DUT: same wiring as src/top.v -------------------------------------------------
    wire [9:0] pixel_x, pixel_y;
    wire [2:0] bar = pixel_x / 90;
    wire [7:0] r = (bar == 0 || bar == 1 || bar == 4 || bar == 5) ? 8'hFF : 8'h00;
    wire [7:0] g = (bar == 0 || bar == 1 || bar == 2 || bar == 3) ? 8'hFF : 8'h00;
    wire [7:0] b = (bar == 0 || bar == 2 || bar == 4 || bar == 6) ? 8'hFF : 8'h00;
    wire        audio_valid;
    wire [15:0] audio;
    wire [29:0] t;
    tone_1k tone (.clk(clk), .rst_n(rst_n), .valid(audio_valid), .sample(audio));
    hdmi_tx #(.RGB_QUANT(2'b10)) tx (
        .clk_pixel(clk), .rst_n(rst_n), .pixel_x(pixel_x), .pixel_y(pixel_y),
        .video_rgb({r, g, b}), .audio_valid(audio_valid), .audio_l(audio), .audio_r(audio),
        .tmds(t));

    // ---- sink-side decoder -------------------------------------------------------------
    wire [9:0] s0 = t[9:0], s1 = t[19:10], s2 = t[29:20];
    wire [4:0] d0 = terc4_dec(s0), d1 = terc4_dec(s1), d2 = terc4_dec(s2);
    wire data_gb  = (s1 == REF_GB_1) && (s2 == REF_GB_1) && d0[4];
    wire video_gb = (s0 == REF_VGB_02) && (s1 == REF_GB_1) && (s2 == REF_VGB_02);

    integer pos = -1, j, errors = 0;
    reg [31:0] hdr;
    reg [63:0] sp [0:3];
    integer nsamp = 0, nacr = 0, naif = 0, navi = 0, npkt = 0;
    reg signed [15:0] samples [0:1023];
    realtime t_first, t_last;
    integer vpos = -1, vline_checked = 0;
    reg prev_vgb = 0;

    task fail(input [8*80-1:0] msg); begin errors = errors + 1; if (errors < 6) $display("FAIL: %0s", msg); end endtask

    task packet;
        reg [19:0] cts, n;
        begin
            npkt = npkt + 1;
            if (bch({32'd0, hdr}, 32) != 0) fail("header BCH");
            for (j = 0; j < 4; j = j + 1) if (bch(sp[j], 64) != 0) begin $display("  pkt %0d type %h hb1 %h sp%0d=%h t=%0t", npkt, hdr[7:0], hdr[15:8], j, sp[j], $time); fail("subpacket BCH"); end
            case (hdr[7:0])
                8'h02: for (j = 0; j < 4; j = j + 1) if (hdr[8 + j]) begin        // audio sample
                    if (sp[j][23:8] !== sp[j][47:32]) fail("L != R");
                    if (nsamp == 0) t_first = $realtime;
                    t_last = $realtime;
                    if (nsamp < 1024) samples[nsamp] = sp[j][23:8];
                    nsamp = nsamp + 1;
                end
                8'h01: begin                                                       // ACR
                    cts = {sp[0][11:8], sp[0][23:16], sp[0][31:24]};
                    n   = {sp[0][35:32], sp[0][47:40], sp[0][55:48]};
                    if (cts != 27000 || n != 6144) begin
                        $display("ACR CTS=%0d N=%0d", cts, n); fail("ACR values");
                    end
                    nacr = nacr + 1;
                end
                8'h84: naif = naif + 1;                                            // Audio InfoFrame
                8'h82: navi = navi + 1;                                            // AVI InfoFrame
                default: ;
            endcase
        end
    endtask

    always @(posedge clk) if (rst_n) begin
        // data islands: GB GB | 32-symbol packets ... | GB GB
        if (data_gb) pos = 0;
        else if (pos >= 0 && d0[4] && d1[4] && d2[4]) begin
            hdr[pos] = d0[2];
            for (j = 0; j < 4; j = j + 1) begin
                sp[j][2*pos]     = d1[j];
                sp[j][2*pos + 1] = d2[j];
            end
            if (pos == 31) begin packet; pos = 0; end
            else pos = pos + 1;
        end else pos = -1;

        // one video line: after the video guard band come 720 pixels
        if (prev_vgb && !video_gb) vpos = 0;
        if (vpos >= 0 && !vline_checked) begin
            if ({tmds_dec(s2), tmds_dec(s1), tmds_dec(s0)} !==
                {((vpos/90==0||vpos/90==1||vpos/90==4||vpos/90==5) ? 8'hFF : 8'h00),
                 ((vpos/90==0||vpos/90==1||vpos/90==2||vpos/90==3) ? 8'hFF : 8'h00),
                 ((vpos/90==0||vpos/90==2||vpos/90==4||vpos/90==6) ? 8'hFF : 8'h00)})
                fail("video pixel");
            vpos = vpos + 1;
            if (vpos == 720) begin vpos = -1; vline_checked = 1; end
        end
        prev_vgb = video_gb;
    end

    // ---- checks ------------------------------------------------------------------------
    integer k, want;
    real rate;
    initial begin
        repeat (10) @(posedge clk);
        rst_n = 1;
        wait (nsamp >= 480);                    // 10 cycles of the tone
        for (k = 0; k < 480; k = k + 1) begin
            want = $rtoi(8192.0 * $sin(2.0 * 3.14159265358979 * k / 48.0) + (k % 48 < 24 ? 0.5 : -0.5));
            if (k % 24 == 0) want = 0;
            if (samples[k] !== want[15:0]) begin
                if (errors < 6) $display("sample %0d = %0d want %0d", k, samples[k], want);
                fail("sine sample");
            end
        end
        rate = (nsamp - 1) / ((t_last - t_first) * 1e-9);
        if (rate < 47000 || rate > 49000) fail("sample rate");
        if (nacr == 0) fail("no ACR packet");
        if (!vline_checked) fail("no video line decoded");
        wait (naif >= 1 && navi >= 1);          // sent once per frame in vertical blanking
        if (errors) $fatal(1, "FAIL: %0d errors", errors);
        $display("PASS: %0d packets, %0d audio samples = 1 kHz sine, rate %0.0f Hz, %0d ACR, %0d AVI + %0d Audio InfoFrames, bars OK",
                 npkt, nsamp, rate, nacr, navi, naif);
        $finish;
    end

    initial begin #40_000_000; $fatal(1, "FAIL: timeout, %0d samples, %0d packets", nsamp, npkt); end
endmodule

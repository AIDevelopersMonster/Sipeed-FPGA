// HDMI colour bars + caption/timecode + 1 kHz tone, 720x480p59.94 (VIC 2) on the Dock's HDMI port.
// 27 MHz -> rPLL 135 MHz (serial, DDR) -> CLKDIV /5 -> 27 MHz pixel clock.
// HDMI transmitter (data islands, audio packets, InfoFrames) is src/hdmi/,
// taken unchanged from the Apple_TN20K project. LED0 on = PLL locked.
`include "src/hdmi/hdmi_defs.vh"
module top (
    input  wire       clk,
    input  wire       rst_n,
    output wire [2:0] tmds_d_p,
    output wire [2:0] tmds_d_n,
    output wire       tmds_clk_p,
    output wire       tmds_clk_n,
    output wire       led_lock_n
);
    wire fclk, lock, pclk;

    rPLL #(
        .FCLKIN("27"), .DEVICE("GW2A-18C"),
        .IDIV_SEL(0),            // /1
        .FBDIV_SEL(4),           // x5  -> 135 MHz
        .ODIV_SEL(4),            // VCO = 540 MHz
        .DYN_IDIV_SEL("false"), .DYN_FBDIV_SEL("false"), .DYN_ODIV_SEL("false"),
        .CLKFB_SEL("internal"), .DYN_SDIV_SEL(2)
    ) pll (
        .CLKIN(clk), .CLKFB(1'b0), .RESET(~rst_n), .RESET_P(1'b0),
        .FBDSEL(6'b0), .IDSEL(6'b0), .ODSEL(6'b0), .PSDA(4'b0), .DUTYDA(4'b0), .FDLY(4'b0),
        .CLKOUT(fclk), .LOCK(lock), .CLKOUTP(), .CLKOUTD(), .CLKOUTD3()
    );

    CLKDIV #(.DIV_MODE("5")) div5 (.HCLKIN(fclk), .RESETN(lock), .CALIB(1'b0), .CLKOUT(pclk));

    // reset released two pixel clocks after lock
    reg [1:0] rst_sync = 2'b00;
    always @(posedge pclk or negedge lock)
        if (!lock) rst_sync <= 2'b00;
        else       rst_sync <= {rst_sync[0], 1'b1};
    wire hdmi_rst_n = rst_sync[1];

    // 8 colour bars, 90 px each: white yellow cyan green magenta red blue black
    wire [9:0] pixel_x, pixel_y;
    wire [2:0] bar = pixel_x / 90;
    wire [7:0] r = (bar == 0 || bar == 1 || bar == 4 || bar == 5) ? 8'hFF : 8'h00;
    wire [7:0] g = (bar == 0 || bar == 1 || bar == 2 || bar == 3) ? 8'hFF : 8'h00;
    wire [7:0] b = (bar == 0 || bar == 2 || bar == 4 || bar == 6) ? 8'hFF : 8'h00;

    // caption: "Terence Ang" + drop-frame timecode, advanced at the start of vblank
    wire [31:0] tc;
    wire [23:0] rgb;
    timecode_df tcg (.clk(pclk), .rst_n(hdmi_rst_n),
                     .tick(pixel_x == 10'd0 && pixel_y == `VM_V_ACTIVE), .bcd(tc));
    overlay ov (.x(pixel_x), .y(pixel_y), .bg({r, g, b}), .tc(tc), .rgb(rgb));

    wire        audio_valid;
    wire [15:0] audio;
    tone_1k #(.CLK_HZ(`VM_PIXEL_HZ), .AUDIO_HZ(`VM_AUDIO_HZ)) tone (
        .clk(pclk), .rst_n(hdmi_rst_n), .valid(audio_valid), .sample(audio)
    );

    wire [39:0] sym;
    hdmi_tx #(.RGB_QUANT(2'b10)) tx (       // full-range RGB
        .clk_pixel(pclk), .rst_n(hdmi_rst_n),
        .pixel_x(pixel_x), .pixel_y(pixel_y), .video_rgb(rgb),
        .audio_valid(audio_valid), .audio_l(audio), .audio_r(audio),
        .tmds(sym[29:0])
    );
    assign sym[39:30] = 10'b0000011111;     // TMDS clock lane

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : lane
            wire q;
            OSER10 s (
                .Q(q), .PCLK(pclk), .FCLK(fclk), .RESET(~hdmi_rst_n),
                .D0(sym[10*i+0]), .D1(sym[10*i+1]), .D2(sym[10*i+2]), .D3(sym[10*i+3]), .D4(sym[10*i+4]),
                .D5(sym[10*i+5]), .D6(sym[10*i+6]), .D7(sym[10*i+7]), .D8(sym[10*i+8]), .D9(sym[10*i+9])
            );
            if (i < 3) begin : d
                TLVDS_OBUF b (.I(q), .O(tmds_d_p[i]), .OB(tmds_d_n[i]));
            end else begin : c
                TLVDS_OBUF b (.I(q), .O(tmds_clk_p), .OB(tmds_clk_n));
            end
        end
    endgenerate

    assign led_lock_n = ~lock;
endmodule

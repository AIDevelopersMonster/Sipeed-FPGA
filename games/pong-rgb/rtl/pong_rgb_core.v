// PiKoSoL PONG RGB v1.2 candidate - steerable paddle bounce and selectable AI.
// Hardware domain: same 25.2 MHz pixel clock for UART receiver and game.
// Serial protocol: w/s/i/k=press; W/S/I/K=release; x=release all;
//                  a=toggle right AI; r=restart; 1..4=palette; 5..7=AI difficulty.
// No Atari ROM, sprites or binary code are included.
// SPDX-License-Identifier: MIT
module pong_rgb_core (
    input  wire       clk,
    input  wire       reset_n,
    input  wire [7:0] rx_byte,
    input  wire       rx_valid,
    output reg  [1:0] palette,
    output reg        ai_on,
    input  wire       s_axis_tvalid,
    output wire       s_axis_tready,
    input  wire [23:0] s_axis_tdata,
    input  wire [0:0] s_axis_tuser,
    output wire       m_axis_tvalid,
    input  wire       m_axis_tready,
    output wire [23:0] m_axis_tdata,
    output wire [0:0] m_axis_tuser
);
    assign s_axis_tready = m_axis_tready;
    assign m_axis_tvalid = s_axis_tvalid;
    assign m_axis_tuser = s_axis_tuser;
    wire accepted = s_axis_tvalid && s_axis_tready;
    wire frame_tick = accepted && s_axis_tuser[0];

    reg up1, down1, up2, down2, restart_pulse;
    reg [1:0] ai_level; // 0=Easy, 1=Normal (default), 2=Hard
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            up1<=0; down1<=0; up2<=0; down2<=0;
            ai_on<=1; palette<=0; ai_level<=2'd1; restart_pulse<=0;
        end else begin
            restart_pulse <= 0;
            if (rx_valid) begin
                case (rx_byte)
                    8'h77: up1 <= 1;       // w pressed
                    8'h57: up1 <= 0;       // W released
                    8'h73: down1 <= 1;     // s
                    8'h53: down1 <= 0;     // S
                    8'h69: up2 <= 1;       // i
                    8'h49: up2 <= 0;       // I
                    8'h6b: down2 <= 1;     // k
                    8'h4b: down2 <= 0;     // K
                    8'h78: begin           // x: release everything
                        up1<=0;down1<=0;up2<=0;down2<=0;
                    end
                    8'h61: ai_on <= ~ai_on;    // a
                    8'h72: restart_pulse <= 1; // r
                    8'h31: palette <= 2'd0; // 1 Neon
                    8'h32: palette <= 2'd1; // 2 Retro
                    8'h33: palette <= 2'd2; // 3 Matrix
                    8'h34: palette <= 2'd3; // 4 Sunset
                    8'h35: ai_level <= 2'd0; // 5 Easy
                    8'h36: ai_level <= 2'd1; // 6 Normal
                    8'h37: ai_level <= 2'd2; // 7 Hard
                    default: ;
                endcase
            end
        end
    end

    reg [9:0] p1_y, p2_y, ball_x, ball_y;
    reg vx_left, vy_up;
    reg [2:0] vy_pixels;  // Vertical speed (1..5 pixels/frame).
    reg [7:0] entropy;    // Small deterministic LFSR, sampled at rally events.
    reg [3:0] score1, score2;
    reg game_over, winner_right;
    reg [5:0] blink_phase;
    wire win_flash = !blink_phase[4];
    // AI deliberately differs in both movement speed and reaction distance.
    // Hard mode is responsive but does not know future paddle-hit angles.
    wire [9:0] ai_step = (ai_level==2'd0) ? 10'd1 :
                         (ai_level==2'd1) ? 10'd2 : 10'd4;
    wire [9:0] ai_reaction_x = (ai_level==2'd0) ? 10'd505 :
                               (ai_level==2'd1) ? 10'd415 : 10'd350;
    wire [9:0] ai_target_y = (!vx_left && ball_x>=ai_reaction_x) ?
                              (ball_y+10'd4) : 10'd240;

    // 4-bit bounce descriptor: [3]=up, [2:0]=speed.
    // Impact near paddle tips is steep; near centre is shallow. The centre
    // uses a PRNG bit to prevent a long sequence of identical rallies.
    function [3:0] reflected_dy;
        input [9:0] centre;
        input [9:0] paddle_top;
        input [7:0] salt;
        begin
            if      (centre < paddle_top + 10'd10) reflected_dy = {1'b1, 3'd5};
            else if (centre < paddle_top + 10'd22) reflected_dy = {1'b1, 3'd4};
            else if (centre < paddle_top + 10'd30) reflected_dy = {1'b1, 3'd3};
            else if (centre < paddle_top + 10'd34) reflected_dy = {1'b1, 3'd2};
            else if (centre < paddle_top + 10'd38)
                reflected_dy = {salt[0], (salt[1] ? 3'd2 : 3'd1)};
            else if (centre < paddle_top + 10'd42) reflected_dy = {1'b0, 3'd2};
            else if (centre < paddle_top + 10'd50) reflected_dy = {1'b0, 3'd3};
            else if (centre < paddle_top + 10'd62) reflected_dy = {1'b0, 3'd4};
            else reflected_dy = {1'b0, 3'd5};
        end
    endfunction
    wire [3:0] bounce1 = reflected_dy(ball_y+10'd4, p1_y, entropy);
    wire [3:0] bounce2 = reflected_dy(ball_y+10'd4, p2_y, entropy);

    wire hit_p1 = ((ball_y + 10'd8) >= p1_y) && (ball_y < (p1_y + 10'd72));
    wire hit_p2 = ((ball_y + 10'd8) >= p2_y) && (ball_y < (p2_y + 10'd72));
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            p1_y<=10'd204; p2_y<=10'd204;
            ball_x<=10'd316; ball_y<=10'd236;
            vx_left<=1; vy_up<=0; vy_pixels<=3'd3; entropy<=8'hA5;
            score1<=0; score2<=0;
            game_over<=0; winner_right<=0; blink_phase<=0;
        end else if (restart_pulse) begin
            p1_y<=10'd204; p2_y<=10'd204;
            ball_x<=10'd316; ball_y<=10'd236;
            vx_left<=1; vy_up<=0; vy_pixels<=3'd3;
            score1<=0; score2<=0;
            game_over<=0; winner_right<=0; blink_phase<=0;
        end else if (frame_tick) begin
            entropy <= {entropy[6:0],
                        entropy[7] ^ entropy[5] ^ entropy[4] ^ entropy[3]};
            if (game_over) blink_phase <= blink_phase + 6'd1;
            if (!game_over) begin
            // One game step per video frame: independent of UART byte rate.
            if (up1 && !down1 && p1_y>=10'd5) p1_y<=p1_y-10'd5;
            else if(down1 && !up1 && p1_y<=10'd403) p1_y<=p1_y+10'd5;
            if (ai_on) begin
                if (ai_target_y < (p2_y + 10'd35) && p2_y>=ai_step)
                    p2_y<=p2_y-ai_step;
                else if (ai_target_y > (p2_y + 10'd36) &&
                         p2_y <= (10'd408-ai_step))
                    p2_y<=p2_y+ai_step;
            end else if(up2 && !down2 && p2_y>=10'd5)
                p2_y<=p2_y-10'd5;
            else if(down2 && !up2 && p2_y<=10'd403)
                p2_y<=p2_y+10'd5;

            // Paddle contact changes both direction and vertical speed.
            // Move vertically on ordinary travel frames only: this keeps
            // the scored reset and collision response atomic.
            if (vx_left && ball_x<=10'd30 && ball_x>=10'd8 && hit_p1) begin
                vx_left<=0;
                ball_x<=10'd30;
                vy_up<=bounce1[3];
                vy_pixels<=bounce1[2:0];
            end else if (!vx_left && ball_x>=10'd600 &&
                         ball_x<=10'd618 && hit_p2) begin
                vx_left<=1;
                ball_x<=10'd600;
                vy_up<=bounce2[3];
                vy_pixels<=bounce2[2:0];
            end else if (vx_left && ball_x<=10'd7) begin
                if (score2==4'd8) begin
                    score2<=4'd9; game_over<=1; winner_right<=1;
                end else score2<=score2+4'd1;
                ball_x<=10'd316; ball_y<=10'd236;
                vx_left<=0;
                vy_up<=entropy[0];
                vy_pixels<=3'd2 + {1'b0, entropy[2:1]};
            end else if (!vx_left && ball_x>=10'd625) begin
                if (score1==4'd8) begin
                    score1<=4'd9; game_over<=1; winner_right<=0;
                end else score1<=score1+4'd1;
                ball_x<=10'd316; ball_y<=10'd236;
                vx_left<=1;
                vy_up<=entropy[0];
                vy_pixels<=3'd2 + {1'b0, entropy[2:1]};
            end else begin
                ball_x <= vx_left ? ball_x-10'd4 : ball_x+10'd4;
                if (vy_up && ball_y <= (10'd6 + {7'd0,vy_pixels})) begin
                    vy_up<=0;
                    ball_y<=10'd6;
                end else if (!vy_up &&
                             ball_y >= (10'd466 - {7'd0,vy_pixels})) begin
                    vy_up<=1;
                    ball_y<=10'd466;
                end else begin
                    ball_y <= vy_up ? ball_y-{7'd0,vy_pixels} :
                                      ball_y+{7'd0,vy_pixels};
                end
            end
            end // !game_over
        end
    end

    // HDMI pixel positions. Frame start is the tuser[0] marker from SVO.
    reg [9:0] scan_x,scan_y;
    wire [9:0] px = s_axis_tuser[0] ? 10'd0 : scan_x;
    wire [9:0] py = s_axis_tuser[0] ? 10'd0 : scan_y;
    always @(posedge clk or negedge reset_n) begin
        if(!reset_n) begin scan_x<=0;scan_y<=0;end
        else if(accepted) begin
            if(s_axis_tuser[0]) begin scan_x<=10'd1;scan_y<=0;end
            else if(scan_x==10'd639) begin
                scan_x<=0;
                scan_y <= (scan_y==10'd479) ? 10'd0 : scan_y+10'd1;
            end else scan_x<=scan_x+10'd1;
        end
    end

    // Synthesizable seven-segment score glyphs, without external font ROM.
    function digit_pixel;
        input [3:0] d;
        input [5:0] x;
        input [5:0] y;
        reg [6:0] seg; // a b c d e f g
        begin
            case (d)
                0:seg=7'b1111110;
                1:seg=7'b0110000;
                2:seg=7'b1101101;
                3:seg=7'b1111001;
                4:seg=7'b0110011;
                5:seg=7'b1011011;
                6:seg=7'b1011111;
                7:seg=7'b1110000;
                8:seg=7'b1111111;
                9:seg=7'b1111011;
                default:seg=7'b0000001;
            endcase
            digit_pixel =
               (seg[6] && y<6'd5 && x>=6'd5 && x<6'd34) ||
               (seg[5] && x>=6'd33 && y>=6'd5 && y<6'd29) ||
               (seg[4] && x>=6'd33 && y>=6'd29 && y<6'd53) ||
               (seg[3] && y>=6'd52 && x>=6'd5 && x<6'd34) ||
               (seg[2] && x<6'd6 && y>=6'd29 && y<6'd53) ||
               (seg[1] && x<6'd6 && y>=6'd5 && y<6'd29) ||
               (seg[0] && y>=6'd26 && y<6'd32 && x>=6'd5 && x<6'd34);
        end
    endfunction
    wire digit1 = (px>=10'd258 && px<10'd298 &&
                   py>=10'd20 && py<10'd78) &&
                  digit_pixel(score1,px-10'd258,py-10'd20) &&
                  (!game_over || winner_right || win_flash);
    wire digit2 = (px>=10'd342 && px<10'd382 &&
                   py>=10'd20 && py<10'd78) &&
                  digit_pixel(score2,px-10'd342,py-10'd20) &&
                  (!game_over || !winner_right || win_flash);
    wire draw1 = (px>=10'd18 && px<10'd30) && py>=p1_y &&
                 py<(p1_y+10'd72) && (!game_over || winner_right || win_flash);
    wire draw2 = (px>=10'd610 && px<10'd622) && py>=p2_y &&
                 py<(p2_y+10'd72) && (!game_over || !winner_right || win_flash);
    wire draw_ball = !game_over && px>=ball_x && px<(ball_x+10'd9) &&
                     py>=ball_y && py<(ball_y+10'd9);
    wire draw_center = (px>=10'd319 && px<10'd322) && (py[4:0]<5'd15);
    wire draw_border = py<10'd4 || py>=10'd476;
    wire draw_stars = (px[6:0]==7'd38 && py[6:0]==7'd59);
    // Large, observable right-side digit: AI 1=Easy, 2=Normal, 3=Hard.
    wire [3:0] ai_digit = {2'd0,ai_level} + 4'd1;
    wire draw_ai_level = ai_on && (px>=10'd560 && px<10'd600) &&
                         (py>=10'd35 && py<10'd93) &&
                         digit_pixel(ai_digit,px-10'd560,py-10'd35);

    // Palette values are BGR888 as expected by the SVO HDMI encoder.
    reg [23:0] bg_color, p1_color, p2_color, ball_color, line_color, score_color;
    always @* begin
        case(palette)
            2'd0: begin // Neon: turquoise, pink, gold on midnight blue
                bg_color=24'h1C0C08; p1_color=24'hE8EA22;
                p2_color=24'hC847FF; ball_color=24'h38DBFF;
                line_color=24'h563A32; score_color=24'hE9FFFF;
            end
            2'd1: begin // Retro: high-contrast arcade
                bg_color=24'h0B0B0B; p1_color=24'h66FA66;
                p2_color=24'h80FAFA; ball_color=24'hFFFFFF;
                line_color=24'h484848; score_color=24'hFFFFFF;
            end
            2'd2: begin // Matrix: shades of green
                bg_color=24'h071007; p1_color=24'h12EE1B;
                p2_color=24'h35A627; ball_color=24'h6CFF61;
                line_color=24'h245C1C; score_color=24'h90FF8B;
            end
            default: begin // Sunset: orange and lavender
                bg_color=24'h450A20; p1_color=24'h27A8FF;
                p2_color=24'hF0A7F2; ball_color=24'h59E8FF;
                line_color=24'h854670; score_color=24'hE3EEFF;
            end
        endcase
    end
    assign m_axis_tdata =
        draw_ball         ? ball_color :
        draw1             ? p1_color :
        draw2             ? p2_color :
        (digit1 || digit2) ? score_color :
        (draw_center || draw_border) ? line_color :
        draw_ai_level     ? p2_color :
        draw_stars        ? line_color :
        bg_color;
    wire _unused_svo_data = ^s_axis_tdata;
endmodule

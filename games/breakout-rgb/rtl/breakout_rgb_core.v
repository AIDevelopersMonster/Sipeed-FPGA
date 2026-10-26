// KonSol RetroStation RS-003 Breakout RGB. SOURCE CANDIDATE, UNVERIFIED.
// Independent game mechanics; stream/clock/UART interface matches PiKoSoL Pong.
// Hardware target: Tang Nano 9K, SVO pixel clock 25.2 MHz.
// SPDX-License-Identifier: MIT
module breakout_rgb_core (
 input wire clk, reset_n, input wire [7:0] rx_byte, input wire rx_valid,
 output reg [1:0] palette, output wire ai_on,
 input wire s_axis_tvalid, output wire s_axis_tready,
 input wire [23:0] s_axis_tdata, input wire [0:0] s_axis_tuser,
 output wire m_axis_tvalid, input wire m_axis_tready,
 output wire [23:0] m_axis_tdata, output wire [0:0] m_axis_tuser
);
 assign ai_on = 1'b0;
 assign s_axis_tready = m_axis_tready;
 assign m_axis_tvalid = s_axis_tvalid;
 assign m_axis_tuser = s_axis_tuser;
 wire accept_pixel = s_axis_tvalid && s_axis_tready;
 wire frame_tick = accept_pixel && s_axis_tuser[0];

 // Web Serial uses keydown w/s for left/right and W/S for keyup.
 // 'p' / Space start, 'r' restarts, 'x' releases all keys; 1..4 palette.
 reg left_pressed, right_pressed, start_pending, restart_pending;
 always @(posedge clk or negedge reset_n) begin
   if (!reset_n) begin
     left_pressed<=0; right_pressed<=0; start_pending<=0;
     restart_pending<=0; palette<=0;
   end else begin
     if (frame_tick) begin start_pending<=0; restart_pending<=0; end
     if (rx_valid) begin
       case(rx_byte)
         8'h77: left_pressed<=1; // w
         8'h57: left_pressed<=0; // W
         8'h73: right_pressed<=1; // s
         8'h53: right_pressed<=0; // S
         8'h78: begin left_pressed<=0;right_pressed<=0;end
         8'h70,8'h20: start_pending<=1; // p/space
         8'h72: restart_pending<=1;
         8'h31: palette<=0;
         8'h32: palette<=1;
         8'h33: palette<=2;
         8'h34: palette<=3;
         default: ;
       endcase
     end
   end
 end
 localparam [1:0] ST_READY=0, ST_PLAY=1, ST_WON=2, ST_LOST=3;
 reg [1:0] state;
 reg [9:0] paddle_x, ball_x, ball_y;
 reg dx_left, dy_up;
 reg [31:0] bricks;
 reg [2:0] lives;
 reg [5:0] hits;
 reg [5:0] blink;
 wire [9:0] ball_right = ball_x + 10'd8;
 wire [9:0] ball_bottom = ball_y + 10'd8;
 wire paddle_hit = (ball_bottom >= 10'd429) && (ball_y <= 10'd435)
                   && (ball_right >= paddle_x) && (ball_x < paddle_x+10'd78);
 // 8 columns, 4 rows, 56x19 bricks, 64x28 pitch.
 wire inside_bricks = (ball_right >= 10'd64) && (ball_x < 10'd568)
                   && (ball_bottom >= 10'd80) && (ball_y < 10'd188);
 wire [9:0] bx_rel = (ball_x>=10'd64) ? ball_x-10'd64 : 10'd0;
 wire [9:0] by_rel = (ball_y>=10'd80) ? ball_y-10'd80 : 10'd0;
 wire [2:0] ball_col = bx_rel[8:6];
 // integer / 28 is deliberately limited to the active brick band
 reg [1:0] ball_row;
 always @* begin
   if (by_rel < 10'd28) ball_row=0;
   else if(by_rel<10'd56) ball_row=1;
   else if(by_rel<10'd84) ball_row=2;
   else ball_row=3;
 end
 wire [5:0] ball_brick_index={ball_row,ball_col};
 wire brick_hit=inside_bricks && (bx_rel[5:0]<6'd56) &&
    ((by_rel<10'd28) ? (by_rel<10'd19) :
     (by_rel<10'd56) ? (by_rel-10'd28<10'd19) :
     (by_rel<10'd84) ? (by_rel-10'd56<10'd19) :
                        (by_rel-10'd84<10'd19)) &&
    bricks[ball_brick_index];
 always @(posedge clk or negedge reset_n) begin
   if(!reset_n) begin
     paddle_x<=10'd281;ball_x<=10'd316;ball_y<=10'd414;
     dx_left<=0;dy_up<=1;state<=ST_READY;
     bricks<=32'hFFFFFFFF;hits<=0;lives<=3;blink<=0;
   end else if(frame_tick) begin
     blink<=blink+6'd1;
     if(restart_pending) begin
       paddle_x<=10'd281;ball_x<=10'd316;ball_y<=10'd414;
       dx_left<=0;dy_up<=1;state<=ST_READY;
       bricks<=32'hFFFFFFFF;hits<=0;lives<=3;
     end else begin
       if(left_pressed && !right_pressed && paddle_x>=10'd6)
          paddle_x<=paddle_x-10'd6;
       else if(right_pressed && !left_pressed && paddle_x<=10'd556)
          paddle_x<=paddle_x+10'd6;
       case(state)
         ST_READY: begin
           ball_x<=paddle_x+10'd35;ball_y<=10'd414;
           if(start_pending) state<=ST_PLAY;
         end
         ST_PLAY: begin
           if(ball_y>=10'd466 && !dy_up) begin
             if(lives==3'd1) begin lives<=0;state<=ST_LOST;end
             else begin lives<=lives-3'd1;state<=ST_READY;end
             ball_x<=paddle_x+10'd35;ball_y<=10'd414;
             dx_left<=~dx_left;dy_up<=1;
           end else if (bricks != 0 && brick_hit) begin
             bricks[ball_brick_index]<=1'b0;
             hits<=hits+6'd1;
             dy_up<=~dy_up;
             if(bricks == (32'h00000001 << ball_brick_index)) state<=ST_WON;
           end else if (dy_up && ball_y<=10'd5) begin
             dy_up<=0;ball_y<=10'd5;
           end else if ((dx_left && ball_x<=10'd5) ||
                        (!dx_left && ball_x>=10'd627)) begin
             dx_left<=~dx_left;
           end else if (!dy_up && paddle_hit) begin
             dy_up<=1;
             dx_left <= (ball_x+10'd4 < paddle_x+10'd39);
             ball_y<=10'd421;
           end else begin
             ball_x<=dx_left ? ball_x-10'd3 : ball_x+10'd3;
             ball_y<=dy_up ? ball_y-10'd3 : ball_y+10'd3;
           end
         end
         default: ;
       endcase
     end
   end
 end
 reg [9:0] scan_x, scan_y;
 wire [9:0] px=s_axis_tuser[0] ? 10'd0 : scan_x;
 wire [9:0] py=s_axis_tuser[0] ? 10'd0 : scan_y;
 always @(posedge clk or negedge reset_n) begin
   if(!reset_n) begin scan_x<=0;scan_y<=0;end
   else if(accept_pixel) begin
     if(s_axis_tuser[0]) begin scan_x<=1;scan_y<=0;end
     else if(scan_x==10'd639) begin
       scan_x<=0; scan_y <= scan_y==10'd479 ? 10'd0 : scan_y+10'd1;
     end else scan_x<=scan_x+10'd1;
   end
 end
 wire [9:0] px_rel = (px>=10'd64) ? px-10'd64 : 10'd0;
 wire [9:0] py_rel = (py>=10'd80) ? py-10'd80 : 10'd0;
 wire [2:0] render_col=px_rel[8:6];
 reg [1:0] render_row;
 always @* begin
   if(py_rel<10'd28)render_row=0;
   else if(py_rel<10'd56)render_row=1;
   else if(py_rel<10'd84)render_row=2;
   else render_row=3;
 end
 wire [5:0] render_index={render_row,render_col};
 wire brick_pixel = px>=10'd64 && px<10'd568 && py>=10'd80 && py<10'd188 &&
   px_rel[5:0]<6'd56 &&
   ((py_rel<10'd28) ? (py_rel<10'd19) :
    (py_rel<10'd56) ? (py_rel-10'd28<10'd19) :
    (py_rel<10'd84) ? (py_rel-10'd56<10'd19) :
                      (py_rel-10'd84<10'd19)) &&
   bricks[render_index];
 wire paddle_pixel = py>=10'd434 && py<10'd445 &&
                     px>=paddle_x && px<paddle_x+10'd78;
 wire ball_pixel = py>=ball_y && py<ball_y+10'd8 &&
                   px>=ball_x && px<ball_x+10'd8;
 wire border_pixel = px<10'd4 || px>=10'd636 || py<10'd4;
 wire ready_pixel = (state==ST_READY && blink[4] &&
                     px>=10'd270 && px<10'd368 && py>=10'd320 && py<10'd329);
 wire end_pixel = ((state==ST_WON || state==ST_LOST) &&
                   blink[4] && px>=10'd160 && px<10'd480 &&
                   py>=10'd308 && py<10'd335);
 // Three simple life pips and score as visually countable brick rows.
 wire life_pixel = (py>=10'd26 && py<10'd39) &&
    ((px>=10'd32 && px<10'd45 && lives>=1) ||
     (px>=10'd54 && px<10'd67 && lives>=2) ||
     (px>=10'd76 && px<10'd89 && lives>=3));
 wire [23:0] bg = palette==0 ? 24'h150A15 :
                        palette==1 ? 24'h0A0A0A :
                        palette==2 ? 24'h0C1909 : 24'h251020;
 wire [23:0] brick_color = render_row==0 ? 24'h3838FF :
                           render_row==1 ? 24'h20A8FF :
                           render_row==2 ? 24'h28E8B8 : 24'hB8FC38;
 assign m_axis_tdata =
     brick_pixel ? brick_color :
     paddle_pixel ? 24'hE9FD30 :
     ball_pixel ? 24'hFFFFFF :
     life_pixel ? 24'h36FF36 :
     (ready_pixel || end_pixel) ? 24'hF16BFB :
     border_pixel ? 24'h777777 : bg;
 wire _unused = ^s_axis_tdata ^ hits[0];
endmodule

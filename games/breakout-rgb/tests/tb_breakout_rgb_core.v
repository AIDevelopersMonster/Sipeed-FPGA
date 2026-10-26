// RS-003 Breakout source-candidate smoke test; run with Icarus Verilog.
`timescale 1ns/1ps
module tb_breakout_rgb_core;
reg clk=0; always #5 clk=~clk;
reg reset_n=0,rx_valid=0; reg [7:0] rx_byte=0; reg [0:0] user=0;
wire [1:0] palette; wire ai_on,ready,out_valid; wire [23:0] pixel; wire [0:0] out_user;
breakout_rgb_core dut(
 .clk(clk),.reset_n(reset_n),.rx_byte(rx_byte),.rx_valid(rx_valid),
 .palette(palette),.ai_on(ai_on),
 .s_axis_tvalid(1'b1),.s_axis_tready(ready),.s_axis_tdata(24'd0),
 .s_axis_tuser(user),.m_axis_tvalid(out_valid),.m_axis_tready(1'b1),
 .m_axis_tdata(pixel),.m_axis_tuser(out_user));
task frame;begin
 @(negedge clk);user=1;
 @(negedge clk);user=0;
 @(negedge clk);
end endtask
task send; input [7:0] key; begin
 @(negedge clk);rx_byte=key;rx_valid=1;
 @(negedge clk);rx_valid=0;
end endtask
initial begin
 repeat(5)@(negedge clk); reset_n=1;
 repeat(3)@(negedge clk);
 if(dut.state!==0 || dut.lives!==3 || dut.bricks!==32'hffffffff) $fatal(1,"reset");
 send("2"); if(palette!==1) $fatal(1,"palette");
 send("p");frame(); if(dut.state!==1) $fatal(1,"launch");
 send("w");frame(); if(dut.paddle_x>=281) $fatal(1,"paddle");
 send("W");send("r");frame();
 if(dut.state!==0 || dut.lives!==3) $fatal(1,"restart");
 send("p");frame();
 @(negedge clk);dut.ball_x=65;dut.ball_y=82;
 frame(); if(dut.bricks[0]!==0 || dut.hits!==1) $fatal(1,"brick");
 @(negedge clk);dut.ball_x=320;dut.ball_y=467;dut.dy_up=0;
 frame(); if(dut.lives!==2 || dut.state!==0) $fatal(1,"life");
 $display("RS003_BREAKOUT_TB_PASS");$finish;
end
endmodule

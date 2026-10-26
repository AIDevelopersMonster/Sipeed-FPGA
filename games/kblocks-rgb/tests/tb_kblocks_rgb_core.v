// RS-004: self-checking gameplay smoke/regression for Icarus Verilog.
// Tests are deterministic. Physical HDMI and Gowin timing remain separate gates.
`timescale 1ns/1ps
module tb_kblocks_rgb_core;
    reg clk=0;
    always #5 clk=~clk;
    reg reset_n=0,rx_valid=0;
    reg [7:0] rx_byte=0;
    reg [0:0] user=0;
    wire [1:0] palette;
    wire ai_on,ready,out_valid;
    wire [23:0] pixel;
    wire [0:0] out_user;
    integer r,k,o, checks=0;

    kblocks_rgb_core #(.GRAVITY_FRAMES(30), .SOFT_DROP_FRAMES(2),
                        .MOVE_REPEAT_FRAMES(2)) dut (
        .clk(clk),.reset_n(reset_n),.rx_byte(rx_byte),.rx_valid(rx_valid),
        .palette(palette),.ai_on(ai_on),
        .s_axis_tvalid(1'b1),.s_axis_tready(ready),.s_axis_tdata(24'd0),
        .s_axis_tuser(user),.m_axis_tvalid(out_valid),.m_axis_tready(1'b1),
        .m_axis_tdata(pixel),.m_axis_tuser(out_user)
    );

    task frame;
        begin
            @(negedge clk); user=1;
            @(negedge clk); user=0;
            @(negedge clk);
        end
    endtask
    task send;
        input [7:0] code;
        begin
            @(negedge clk); rx_byte=code; rx_valid=1;
            @(negedge clk); rx_valid=0;
        end
    endtask
    task expect_state;
        input [1:0] goal;
        begin
            if(dut.state!==goal) $fatal(1,"state=%d expected=%d",dut.state,goal);
            checks=checks+1;
        end
    endtask
    function integer four_count;
        input [15:0] mask;
        integer i;
        begin
            four_count=0;
            for(i=0;i<16;i=i+1) four_count=four_count+mask[i];
        end
    endfunction

    initial begin
        repeat(6) @(negedge clk);
        reset_n=1;
        repeat(3) @(negedge clk);
        expect_state(0);
        if(dut.lines_ones!==0 || dut.lines_tens!==0) $fatal(1,"reset score");
        for(r=0;r<20;r=r+1)
            if(dut.field_rows[r]!==10'd0) $fatal(1,"row %d not reset",r);
        checks=checks+2;

        for(k=0;k<7;k=k+1)
            for(o=0;o<4;o=o+1)
                if(four_count(dut.shape_mask(k,o))!==4)
                    $fatal(1,"shape %d rotation %d has wrong population",k,o);
        checks=checks+28;
        if(dut.can_place(3'd0,2'd0,5'd7,5'd0)!==0)
            $fatal(1,"horizontal I outside right boundary");
        if(dut.can_place(3'd0,2'd1,5'd0,5'd17)!==0)
            $fatal(1,"vertical I outside bottom boundary");
        checks=checks+2;

        send("3");
        if(palette!==2) $fatal(1,"palette command");
        send("p");frame();expect_state(1);
        send("a");frame();
        if(dut.piece_x!==5'd2) $fatal(1,"left movement, got %d",dut.piece_x);
        checks=checks+1;
        send("A");
        send("w");frame();
        if(dut.piece_rot!==1) $fatal(1,"rotation failed");
        checks=checks+1;

        send("r");frame();expect_state(0);
        send("p");frame();expect_state(1);
        send("s");frame();frame();
        if(dut.piece_y!==5'd1) $fatal(1,"soft drop not accelerated");
        checks=checks+1;
        send("S");

        // Double-line removal: O piece at x8 fills the remaining two cells
        // of both bottom rows; the compactor must NOT skip adjacent lines.
        @(negedge clk);
        dut.piece_kind=3'd1; dut.piece_rot=0;
        dut.piece_x=5'd8; dut.piece_y=5'd18;
        dut.fall_ctr=8'd29;
        dut.field_rows[18]=10'h0FF;
        dut.field_rows[19]=10'h0FF;
        frame();expect_state(2);
        if(dut.field_rows[18]!==10'h3FF || dut.field_rows[19]!==10'h3FF)
            $fatal(1,"lock must merge all cells in each row");
        checks=checks+1;
        repeat(70) @(negedge clk);
        expect_state(1);
        if(dut.lines_ones!==2 || dut.field_rows[19]!==0)
            $fatal(1,"double-line clear fail: lines=%d bottom=%h",
                   dut.lines_ones,dut.field_rows[19]);
        checks=checks+1;

        // Single-line clear and row shift: O at x0 contributes bits 0/1
        // while row19 already contains bits 2..9.
        @(negedge clk);
        dut.piece_kind=3'd1; dut.piece_rot=0;
        dut.piece_x=5'd0; dut.piece_y=5'd18;
        dut.fall_ctr=8'd29;
        dut.field_rows[18]=0;
        dut.field_rows[19]=10'h3FC;
        frame();expect_state(2);
        repeat(70) @(negedge clk);
        expect_state(1);
        if(dut.lines_ones!==3 || dut.field_rows[19]!==10'h003)
            $fatal(1,"single-line clear or shift failed");
        checks=checks+1;

        // Top-out: the next T shape overlaps cell (x=4,y=0).
        @(negedge clk);
        for(r=0;r<20;r=r+1) dut.field_rows[r]=0;
        dut.field_rows[0]=10'h010;
        dut.state=1; dut.piece_kind=3'd1; dut.piece_rot=0;
        dut.piece_x=5'd8; dut.piece_y=5'd18;
        dut.fall_ctr=8'd29;
        frame();expect_state(2);
        repeat(70) @(negedge clk);
        expect_state(3);
        send("p");frame();expect_state(1);
        if(dut.field_rows[0]!==0 || dut.lines_ones!==0)
            $fatal(1,"game-over restart did not clear board and score");
        checks=checks+1;

        // SVO stream passthrough never drops tvalid or first-pixel marker.
        user=1;
        #1;
        if(out_valid!==1 || ready!==1 || out_user!==1)
            $fatal(1,"stream handshake or SOF not preserved");
        checks=checks+1;
        user=0;
        $display("RS004_KBLOCKS_TB_PASS checks=%0d",checks);
        $finish;
    end
    initial begin
        #2000000;
        $fatal(1,"TEST TIMEOUT");
    end
endmodule

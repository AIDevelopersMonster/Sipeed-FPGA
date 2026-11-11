`timescale 1ns/1ps
// Stream-through overlay regression: output colors, SOF, stalls, mask snapshot.
module tb_lab04_led_osd;
    reg clk = 0;
    always #5 clk = ~clk;
    reg resetn = 0;
    reg [5:0] mask_pixel = 0;
    reg vld = 0;
    wire rdy;
    reg [23:0] din = 24'h123456;
    reg [0:0] sof = 0;
    wire vo;
    reg ro = 0;
    wire [23:0] dout;
    wire [0:0] sou;
    lab04_led_osd #(.H_ACTIVE(640), .V_ACTIVE(80)) dut(
        .clk_pixel(clk), .resetn_pixel(resetn), .mask_pixel(mask_pixel),
        .s_axis_tvalid(vld), .s_axis_tready(rdy),
        .s_axis_tdata(din), .s_axis_tuser(sof),
        .m_axis_tvalid(vo), .m_axis_tready(ro),
        .m_axis_tdata(dout), .m_axis_tuser(sou)
    );
    integer frame, x, y, checks;
    reg [23:0] expected;
    initial begin
        checks = 0;
        repeat (4) @(negedge clk);
        resetn = 1;
        // first frame mask=01, second frame mask=20 (changed MID first frame).
        for (frame=0; frame<2; frame=frame+1) begin
            for (y=0; y<80; y=y+1) begin
                for (x=0; x<640; x=x+1) begin
                    @(negedge clk);
                    vld=1; ro=1;
                    din=24'h123456;
                    sof=(x==0 && y==0);
                    if (frame==0 && x==0 && y==0) mask_pixel=6'h01;
                    if (frame==0 && x==100 && y==30) mask_pixel=6'h20;
                    // Stall a pixel for 3 cycles: colors, pointers and SOF
                    // must remain unchanged while the ready signal is low.
                    if (frame==0 && x==50 && y==35) begin
                        ro=0;
                        repeat(3) begin
                            #1;
                            if(rdy !== 0 || vo !== 1 || dout !== 24'h20E030)
                                $fatal(1,"ready/valid stall changed output");
                            @(posedge clk); @(negedge clk);
                        end
                        ro=1;
                    end
                    #1;
                    if (rdy !== ro || vo !== vld || sou !== sof)
                        $fatal(1,"stream handshake mismatch");
                    if(y==0 && x==0) begin
                        if (dout !== 24'h123456) $fatal(1,"SOF should be transparent");
                        checks=checks+1;
                    end
                    if(y==35 && x==50) begin
                        expected = (frame==0) ? 24'h20E030 : 24'h303030;
                        if (dout !== expected) $fatal(1,"LED1 fill frame %0d: %h",frame,dout);
                        checks=checks+1;
                    end
                    if(y==35 && x==550) begin
                        expected = (frame==0) ? 24'h303030 : 24'h20E030;
                        if (dout !== expected) $fatal(1,"LED6 fill frame %0d: %h",frame,dout);
                        checks=checks+1;
                    end
                    if(y==35 && x==31) begin
                        if (dout !== 24'hE0E0E0) $fatal(1,"border missing");
                        checks=checks+1;
                    end
                    if(y==35 && x==18) begin
                        if (dout !== 24'h201008) $fatal(1,"HUD background missing");
                        checks=checks+1;
                    end
                    if(y==35 && x==8) begin
                        if (dout !== 24'h123456) $fatal(1,"outside HUD must pass through");
                        checks=checks+1;
                    end
                    @(posedge clk);
                end
            end
        end
        @(negedge clk); vld=0; ro=0;
        if(checks != 12) $fatal(1,"missing checks %0d",checks);
        $display("LAB04_V016_OSD_RTL_PASS checks=%0d frames=2",checks);
        $finish;
    end
    initial begin #2000000; $fatal(1,"OSD bench timeout"); end
endmodule

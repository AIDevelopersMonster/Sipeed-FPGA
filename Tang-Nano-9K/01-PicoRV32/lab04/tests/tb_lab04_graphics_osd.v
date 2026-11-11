`timescale 1ns/1ps
// Two sprite rectangles and atomic COMMIT on SOF; pass-through, overlap, stall.
module tb_lab04_graphics_osd;
    reg clk = 0;
    always #5 clk = ~clk;
    reg resetn = 0;
    reg event_valid = 0;
    reg [3:0] event_index = 0;
    reg [23:0] event_value = 0;
    reg s_valid = 0;
    wire s_ready;
    reg [23:0] s_data = 24'h112233;
    reg [0:0] s_user = 0;
    wire m_valid;
    reg m_ready = 0;
    wire [23:0] m_data;
    wire [0:0] m_user;
    integer frame, y, x, hits = 0;
    reg [23:0] exp_data;
    lab04_graphics_osd #(.H_ACTIVE(32),.V_ACTIVE(16)) dut(
        .clk_pixel(clk), .resetn_pixel(resetn),
        .event_valid(event_valid), .event_index(event_index),
        .event_value(event_value),
        .s_axis_tvalid(s_valid), .s_axis_tready(s_ready),
        .s_axis_tdata(s_data), .s_axis_tuser(s_user),
        .m_axis_tvalid(m_valid), .m_axis_tready(m_ready),
        .m_axis_tdata(m_data), .m_axis_tuser(m_user)
    );
    task cmd(input [3:0] ix, input [23:0] value);
        begin
            @(negedge clk);
            event_valid=1; event_index=ix; event_value=value;
            @(posedge clk); @(negedge clk);
            event_valid=0;
        end
    endtask
    task draw_frame(input integer phase);
        begin
            for (y=0;y<16;y=y+1) begin
                for (x=0;x<32;x=x+1) begin
                    @(negedge clk);
                    s_valid=1; m_ready=1; s_data=24'h112233;
                    s_user=(x==0 && y==0);
                    // Stall a selected cell; its payload and cursor must stick.
                    if (x==5 && y==5) begin
                        m_ready=0;
                        repeat(3) begin
                            #1;
                            if(s_ready!==0 || m_valid!==1 || m_user!==0)
                                $fatal(1,"stall handshake failed");
                            @(posedge clk); @(negedge clk);
                        end
                        m_ready=1;
                    end
                    #1;
                    if(m_valid!==s_valid || s_ready!==m_ready || m_user!==s_user)
                        $fatal(1,"stream handshake mismatch");
                    exp_data=24'h112233;
                    if (phase >= 1 && phase < 3) begin
                        if(x>=2 && x<16 && y>=4 && y<12)
                            exp_data=24'h0000ff;
                        if(x>=8 && x<18 && y>=6 && y<12)
                            exp_data=24'h00ff00; // B above A
                    end
                    if(phase==3) begin
                        if(x>=20 && x<32 && y>=4 && y<12)
                            exp_data=24'h0000ff;
                        if(x>=8 && x<18 && y>=6 && y<12)
                            exp_data=24'h00ff00;
                    end
                    if (phase==4 || phase==5) begin
                        if (x>=20 && x<32 && y>=4 && y<12) begin
                            if (phase==4) begin
                                if(x<22 || y<6 || y>=10)
                                    exp_data=24'h0000ff; // outline only
                            end else begin
                                if(x<22 || y<6 || y>=10 || ((x/8)%2 != (y/8)%2))
                                    exp_data=24'h0000ff; // checker fill
                            end
                        end
                    end
                    if(x==0 && y==0) exp_data=24'h112233;
                    if(m_data !== exp_data)
                        $fatal(1,"phase=%0d xy=%0d,%0d got=%h exp=%h",
                               phase,x,y,m_data,exp_data);
                    hits=hits+1;
                    @(posedge clk);
                end
            end
            @(negedge clk); s_valid=0; m_ready=0;
        end
    endtask
    initial begin
        repeat(4) @(negedge clk); resetn=1;
        draw_frame(0); // no sprite enabled before configuration
        cmd(0,2);  cmd(1,4);  cmd(2,14); cmd(3,8);
        cmd(4,24'h0000ff); cmd(5,1);
        cmd(8,8);  cmd(9,6);  cmd(10,10); cmd(11,6);
        cmd(12,24'h00ff00); cmd(13,1);
        cmd(15,1); // atomic update at next SOF
        draw_frame(1);
        cmd(0,20); // move A in staging WITHOUT commit: must not leak
        draw_frame(2);
        cmd(15,1);
        draw_frame(3);
        cmd(5,3); // A enabled outline-only
        cmd(13,0); // B off
        cmd(15,1);
        draw_frame(4);
        cmd(5,5); // A enabled checker fill
        cmd(15,1);
        draw_frame(5);
        if(hits!=3072) $fatal(1,"frame coverage incomplete %0d",hits);
        $display("LAB04_V017_GRAPHICS_OSD_RTL_PASS pixels=%0d",hits);
        $finish;
    end
    initial begin #100000; $fatal(1,"graphics test timeout"); end
endmodule

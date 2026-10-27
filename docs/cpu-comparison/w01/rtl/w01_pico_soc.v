// W01 dedicated candidate: exact LAB06.2 Pico SoC but Zicntr cycle CSR ENABLED. Original accepted source unchanged.
// Separate from existing PiKoSoL, no Flash/SD/HDMI. Native SoC, not bare CPU.
module w01_pico_soc (
  input wire clk_i, input wire rstn_i, input wire uart0_rxd_i,
  output wire uart0_txd_o, output wire [5:0] led_n_o
);
wire valid, instr, trap;
reg ready;
wire [31:0] addr, wdata;
wire [3:0] wstrb;
wire [31:0] rdata;
picorv32 #(
  .PROGADDR_RESET(32'h00000000), .STACKADDR(32'h80000800),
  .COMPRESSED_ISA(0), .ENABLE_MUL(0), .ENABLE_DIV(0),
  .ENABLE_PCPI(0), .ENABLE_IRQ(0), .ENABLE_COUNTERS(1),
  .ENABLE_COUNTERS64(0), .ENABLE_REGS_DUALPORT(1)
) cpu (
  .clk(clk_i), .resetn(rstn_i), .trap(trap),
  .mem_valid(valid), .mem_instr(instr), .mem_ready(ready),
  .mem_addr(addr), .mem_wdata(wdata), .mem_wstrb(wstrb), .mem_rdata(rdata),
  .pcpi_wr(1'b0), .pcpi_rd(32'b0), .pcpi_wait(1'b0), .pcpi_ready(1'b0), .irq(32'b0)
);
wire rom_sel = (addr[31:14] == 18'd0);
wire ram_sel = (addr[31:11] == 21'h100000);
wire io_sel = (addr[31:8] == 24'h200000);
reg [31:0] rom [0:4095] /* synthesis syn_romstyle = "block_rom" */;
reg [31:0] rom_rd;
initial $readmemh("w01_pico_boot.hex", rom);
always @(posedge clk_i) if (valid && !ready && rom_sel) rom_rd <= rom[addr[13:2]];
reg [31:0] ram [0:511] /* synthesis syn_ramstyle = "block_ram" */;
reg [31:0] ram_rd;
always @(posedge clk_i) if (valid && !ready && ram_sel) begin
 ram_rd <= ram[addr[10:2]];
 if (wstrb[0]) ram[addr[10:2]][7:0] <= wdata[7:0];
 if (wstrb[1]) ram[addr[10:2]][15:8] <= wdata[15:8];
 if (wstrb[2]) ram[addr[10:2]][23:16] <= wdata[23:16];
 if (wstrb[3]) ram[addr[10:2]][31:24] <= wdata[31:24];
end
reg ret_rom, ret_ram;
reg [31:0] io_rd;
assign rdata = ret_rom ? rom_rd : ret_ram ? ram_rd : io_rd;
reg [5:0] gpio;
assign led_n_o = ~gpio;
reg tx_start; reg [7:0] tx_data;
wire tx_busy;
uart_tx_8n1 #(.CLOCK_HZ(27000000),.BAUD(115200)) u_tx(
 .clk(clk_i),.reset_n(rstn_i),.start(tx_start),.data(tx_data),
 .tx(uart0_txd_o),.busy(tx_busy)
);
wire [7:0] rx_data;
wire rx_valid, rx_frame_err;
uart_rx_8n1 #(.CLOCK_HZ(27000000),.BAUD(115200)) u_rx(
 .clk(clk_i),.reset_n(rstn_i),.rx(uart0_rxd_i),
 .data(rx_data),.valid(rx_valid),.framing_error(rx_frame_err)
);
reg [7:0] rx_hold; reg rx_pending,rx_overrun,rx_frame;
always @(posedge clk_i or negedge rstn_i) begin
 if (!rstn_i) begin
  ready<=0;ret_rom<=0;ret_ram<=0;io_rd<=0;gpio<=0;
  tx_start<=0;tx_data<=0;rx_hold<=0;rx_pending<=0;
  rx_overrun<=0;rx_frame<=0;
 end else begin
  ready<=0;tx_start<=0;
  if(rx_valid) begin
    if(rx_pending) rx_overrun<=1;
    rx_hold<=rx_data;rx_pending<=1;
  end
  if(rx_frame_err) rx_frame<=1;
  if(valid&&!ready) begin
   ret_rom<=rom_sel;ret_ram<=ram_sel;
   if(rom_sel||ram_sel) ready<=1;
   else begin
    case(addr)
      32'h20000000: begin
        if(wstrb[0]) gpio<=wdata[5:0];
        io_rd<={26'd0,gpio};ready<=1;
      end
      32'h20000010: begin
        if(wstrb==0) begin io_rd<=0;ready<=1;end
        else if(!tx_busy&&!tx_start) begin
          tx_data<=wdata[7:0];tx_start<=1;ready<=1;
        end
      end
      32'h20000014: begin io_rd<={31'd0,!(tx_busy||tx_start)};ready<=1;end
      32'h20000018: begin
        io_rd<={24'd0,rx_hold};
        if(wstrb==0) rx_pending<=0;
        ready<=1;
      end
      32'h2000001c: begin
        io_rd<={29'd0,rx_frame,rx_overrun,rx_pending};
        if(wstrb!=0) begin rx_frame<=0;rx_overrun<=0;end
        ready<=1;
      end
      default: begin io_rd<=32'hBAD00062;ready<=1;end
    endcase
   end
  end
 end
end
wire unused_signal = trap ^ instr;
endmodule

// HOST-01 composition top: independent UART, FIFO, framing engine and SDHC SPI.
module host01_sector_top(
 input wire clk,input wire reset_n,input wire uart_rx,output wire uart_tx,
 input wire sd_miso,output wire sd_sck,sd_mosi,sd_cs_n
);
 wire [7:0] rx_byte,rx_fifo_byte,tx_fifo_byte,host_tx_byte;
 wire rx_valid,rx_framing,rx_fifo_valid,rx_ready;
 wire host_tx_valid,host_tx_ready,tx_fifo_valid,tx_fifo_ready;
 wire tx_busy,tx_start;
 wire sd_start,sd_busy,sd_done,sd_init;
 wire [31:0] sd_lba;
 wire [8:0] peek_addr;
 wire [7:0] peek_data,sd_error;
 uart_rx_8n1 u_rx(.clk(clk),.reset_n(reset_n),.rx(uart_rx),
   .data(rx_byte),.valid(rx_valid),.framing_error(rx_framing));
 sync_fifo #(.WIDTH(8),.DEPTH(8)) u_rx_fifo(
   .clk(clk),.reset_n(reset_n),.push_valid(rx_valid),.push_ready(),
   .push_data(rx_byte),.pop_valid(rx_fifo_valid),.pop_ready(rx_ready),
   .pop_data(rx_fifo_byte),.full(),.empty(),.count(),.overflow(),.underflow());
 host01_sector_engine u_host(
   .clk(clk),.reset_n(reset_n),.rx_valid(rx_fifo_valid),.rx_ready(rx_ready),
   .rx_data(rx_fifo_byte),.tx_valid(host_tx_valid),.tx_ready(host_tx_ready),
   .tx_data(host_tx_byte),.sd_start(sd_start),.sd_lba(sd_lba),
   .sd_busy(sd_busy),.sd_done(sd_done),.sd_error(sd_error),
   .sd_peek_addr(peek_addr),.sd_peek_data(peek_data));
 sync_fifo #(.WIDTH(8),.DEPTH(8)) u_tx_fifo(
   .clk(clk),.reset_n(reset_n),.push_valid(host_tx_valid),
   .push_ready(host_tx_ready),.push_data(host_tx_byte),
   .pop_valid(tx_fifo_valid),.pop_ready(tx_fifo_ready),
   .pop_data(tx_fifo_byte),.full(),.empty(),.count(),.overflow(),.underflow());
 assign tx_fifo_ready=!tx_busy;
 assign tx_start=tx_fifo_valid&&tx_fifo_ready;
 uart_tx_8n1 u_tx(.clk(clk),.reset_n(reset_n),.start(tx_start),
   .data(tx_fifo_byte),.tx(uart_tx),.busy(tx_busy));
 lab05_sd_read_sector u_sd(.clk(clk),.reset_n(reset_n),
   .start(sd_start),.read_lba(sd_lba),.sd_miso(sd_miso),
   .sd_sck(sd_sck),.sd_mosi(sd_mosi),.sd_cs_n(sd_cs_n),
   .busy(sd_busy),.done(sd_done),.initialized(sd_init),
   .error_code(sd_error),.peek_addr(peek_addr),.peek_data(peek_data));
 wire unused_diag=rx_framing;
endmodule

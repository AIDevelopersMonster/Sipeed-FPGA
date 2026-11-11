// HOST-00 composition-only top. 5 independent modules:
// UART RX -> RX FIFO -> HELLO handler -> TX FIFO -> UART TX.
// Tang Nano 9K: clk pin52, RX pin18, TX pin17. No SD connection.
module host00_uart_hello_top(
 input wire clk,input wire reset_n,input wire uart_rx,
 output wire uart_tx
);
 wire [7:0] rx_byte,rx_fifo_data,answer_byte,tx_fifo_data;
 wire rx_valid,rx_error,rx_ready,rx_fifo_valid;
 wire answer_valid,answer_ready,tx_fifo_valid,tx_fifo_ready;
 wire tx_busy,tx_start;
 wire [3:0] rx_count,tx_count;
 wire rx_overflow,rx_underflow,tx_overflow,tx_underflow;
 uart_rx_8n1 #(.CLOCK_HZ(27000000),.BAUD(115200)) u_rx(
  .clk(clk),.reset_n(reset_n),.rx(uart_rx),
  .data(rx_byte),.valid(rx_valid),.framing_error(rx_error));
 sync_fifo #(.WIDTH(8),.DEPTH(8)) u_rx_fifo(
  .clk(clk),.reset_n(reset_n),
  .push_valid(rx_valid),.push_ready(),.push_data(rx_byte),
  .pop_valid(rx_fifo_valid),.pop_ready(rx_ready),.pop_data(rx_fifo_data),
  .full(),.empty(),.count(rx_count),.overflow(rx_overflow),.underflow(rx_underflow));
 host00_hello u_hello(
  .clk(clk),.reset_n(reset_n),
  .rx_valid(rx_fifo_valid),.rx_ready(rx_ready),.rx_data(rx_fifo_data),
  .tx_valid(answer_valid),.tx_ready(answer_ready),.tx_data(answer_byte));
 sync_fifo #(.WIDTH(8),.DEPTH(8)) u_tx_fifo(
  .clk(clk),.reset_n(reset_n),
  .push_valid(answer_valid),.push_ready(answer_ready),.push_data(answer_byte),
  .pop_valid(tx_fifo_valid),.pop_ready(tx_fifo_ready),.pop_data(tx_fifo_data),
  .full(),.empty(),.count(tx_count),.overflow(tx_overflow),.underflow(tx_underflow));
 assign tx_fifo_ready=!tx_busy;
 assign tx_start=tx_fifo_valid && tx_fifo_ready;
 uart_tx_8n1 #(.CLOCK_HZ(27000000),.BAUD(115200)) u_tx(
  .clk(clk),.reset_n(reset_n),.start(tx_start),
  .data(tx_fifo_data),.tx(uart_tx),.busy(tx_busy));
 // Overflow and framing error are observable in simulation and should
 // become sticky telemetry in the future framed protocol.
 wire unused_diag=rx_error|rx_overflow|rx_underflow|tx_overflow|tx_underflow;
endmodule

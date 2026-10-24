# Synchronous FIFO core v1

Independent, single-clock, parameterized FIFO with valid/ready handshake. No UART/SDHC dependencies. Ports: `push_valid/push_ready/push_data`, `pop_valid/pop_ready/pop_data`, `full/empty/count`, one-cycle `overflow/underflow`. Default `WIDTH=8, DEPTH=8`. The consumer may stall safely using `pop_ready=0`. The module permits push and pop on the same full cycle and preserves FIFO order; an empty FIFO does not bypass the newest push. Small-depth asynchronous head read; do not claim BSRAM inference. Simulation test covers wraparound, backpressure and simultaneous accesses. Does not program hardware.

`iverilog -g2005 -s tb_sync_fifo -o fifo.vvp rtl/sync_fifo.v tests/tb_sync_fifo.v && vvp fifo.vvp`

**Integration:** HOST-00 will use FIFO for UART bytes; LIFO is not suitable for UART byte ordering. A future streaming project can independently choose the required buffering depth and RAM inference architecture.

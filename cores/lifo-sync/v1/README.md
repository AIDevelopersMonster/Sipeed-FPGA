# Synchronous LIFO / stack core v1

Independent, single-clock parameterized LIFO with the same valid/ready external contract as FIFO. Pops the newest item first. Simultaneous accepted push/pop *replaces the old stack top*; the pop result is the old top. The stack rejects pushes when full unless a pop occurs in the same cycle. A pop request on empty is rejected. Simulation test covers stack ordering and error pulses.

`iverilog -g2005 -s tb_sync_lifo -o lifo.vvp rtl/sync_lifo.v tests/tb_sync_lifo.v && vvp lifo.vvp`

LIFO is an educational building block for stack-like tasks and is **not inserted in the UART receive/transmit path**. Packaging and tests are independent from the UART, HOST-00 and SDHC modules.

## Интерактивная учебная страница

[**LIFO: модель стека, указатель вершины, PUSH/POP**](demo/index.html). Самостоятельный офлайн HTML с пошаговыми тактами, заменой вершины при одновременных операциях, переполнением и underflow. Это учебная модель, а не физическое измерение FPGA.

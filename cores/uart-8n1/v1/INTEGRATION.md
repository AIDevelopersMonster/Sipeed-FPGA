# UART v1 composition: strict separation of concerns

```text
Python / SoC application
  |
Host command layer (HELLO, READ_SECTOR) — future project
  |
Framing / CRC / timeout controller — separate module
  |
Optional RX/TX FIFO and backpressure — separate module
  |
UART core v1: RX+TX 8N1 only   <--- this folder
  |
Tang Nano 9K onboard USB-UART bridge
```

**Do not** embed UART RX/TX inside the SDHC SPI controller, FAT32 decoder, Python HOST protocol, or a single large top module.

New projects should include *canonical source paths* `cores/uart-8n1/v1/rtl/uart_tx_8n1.v` and `uart_rx_8n1.v` directly in their build file list, or make a *build-temp snapshot* of these files with SHA-256. Never include two copies with the same module names in a single synthesis.

Existing frozen LAB-02, SD-02, SD-03 and SD-04 files remain as evidence of prior builds; they are not redirected retroactively to the new UART source.

On Tang Nano 9K, previously verified LAB-02 maps UART TX to FPGA pin 17, UART RX to FPGA pin 18, clock to pin 52. Each new board top must supply its own verified CST constraints, run RTL simulations, pass PnR/STA and obtain a new hardware receipt.

**HOST-00 remains paused:** no host protocol, no Python CLI, no board programming or SD-write RTL is added by this UART extraction. A future HOST-00 must first reuse these components and implement its *own independent* byte framing, backpressure and card-block protocol. No UART component should know what an SD LBA means.

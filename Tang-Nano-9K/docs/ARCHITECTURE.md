# Архитектура: CPU/SoC comparison line

## Принцип разделения

```
                 common/ software-visible MMIO contract
                                  |
        +-------------------------+------------------------+
        |                |                 |               |
   PicoRV32          NEORV32           LiteX/Vex         Rocket
   native memory     custom bus        Wishbone/CSR      TileLink/adapter
        |                |                 |               |
   board adapter    board adapter      board adapter    board adapter
        |                |                 |               |
   Nano 9K          Nano 9K           Primer 25K       Primer 25K (?)
```

The same software-visible interface is implemented **through separate adapters**. Do not force CPU cores to use a false identical bus; every bus has distinct handshake/stalling/addressing semantics.

## Stage 01 v0.1

- CPU: external ISC-licensed PicoRV32, pinned by SHA, RV32I configuration.
- Boot ROM: 1 KiB constant program ROM (33 code words + default NOP). The first stage deliberately uses a small case ROM and avoids external Flash/PSRAM.
- Memory map: `0x00000000..0x000003FF` boot ROM; `0x20000000..0x200000FF` MMIO.
- Output: 6 active-low LEDs (pins 10,11,13,14,15,16), UART TX pin 17, UART RX pin 18 (RX reserved), clock pin 52, reset pin 3.
- No RAM, stack, interrupts, DDR/PSRAM, assembler toolchain or external firmware loader in v0.1.
- Boot emits `PICO\n`, performs a signature check, stores firmware marker and animates LEDs from a free-running hardware counter.

## Portability rules

- No vendor IP or hardcoded pins inside common compute kernels.
- Each board gets its own `.cst`/PLL/BRAM/SDRAM/constraints.
- Physical RAM size, initial boot address, clocks and reset polarity are recorded per platform.
- For each benchmark freeze source revision, architecture flags, cache settings, memory system, clock, tool versions and ISA options.
- Clock domain crossing, setup/hold and placement reports are part of acceptance. Simulation alone cannot establish these.

## No-claims

No claim that these four CPU systems are equally fast or resource-compatible. LiteX is a SoC construction framework rather than a CPU. Rocket is not yet confirmed to fit on Primer 25K; the existing reduced RV32IC implementation for Primer 20K is a reference only.

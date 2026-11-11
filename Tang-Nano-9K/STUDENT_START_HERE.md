# PicoRV32 / Tang Nano 9K — student start

Two independent routes:

- **Ready image, no FPGA development tools:** [Russian student guide](docs/STUDENT_QUICKSTART_RU.md) / [English student guide](docs/STUDENT_QUICKSTART_EN.md).
- **Full engineering route:** [Russian programming guide](docs/PICORV32_PROGRAMMING_RU.md) / [English programming guide](docs/PICORV32_PROGRAMMING_EN.md).

The ready-made student package is generated using `tools/New-PicoRV32StudentKit.ps1` from the *locally built* and hardware-tested `picorv32_nano9k.fs`. It is distributed separately as a GitHub Release asset; `*.fs` files are intentionally excluded from Git.

**Memory:** `.fs` already includes the PicoRV32 boot ROM program. SRAM configuration is temporary. Writing persistent configuration uses **embedded FPGA Flash** (not external SPI Flash). v0.1 does not require a separate CPU firmware download.

Validated 2026-10-19: model, RTL, Gowin STA at 27 MHz, SRAM programming, UART `PICO` on COM10 and repeating LED animation. Embedded Flash programming is not yet independently confirmed.

# LAB-06.2A — PicoRV32 minimal native SoC, Tang Nano 9K

**Status: SOURCE PREPARED. SIM / FIT / STA / BOARD NOT RUN.**

A separate reference SoC for later controlled comparison with NEORV32 LAB-06.1 (which is already BOARD BASIC PASS). Nothing under LAB-04, Pong, RetroStation or the accepted NEORV32 bitstream is modified.

- Real pinned PicoRV32: `ef203c2b0a3fb793280f5114941416c425c5b461`, ISC upstream.
- RV32I `-march=rv32i -mabi=ilp32`, GCC `-Os`, no M/C/IRQ/performance counters.
- 27 MHz, 16 KiB on-chip boot ROM, 2 KiB RAM, separate PicoRV32 UART TX/RX, six LEDs.
- FPGA I/O pinout will be matched to the accepted LAB-06.1 at later FIT stage.
- First functional firmware: `PICORV32 READY\r\n` (16 bytes), GPIO `0x15` to `0x2A`. NEORV32 initial banner is 15 bytes, so **not a throughput comparison**.
- This is a **native-SoC** trial, not a bare-CPU area comparison. The UART and MMIO are different hardware from NEORV32 native peripherals, and no equal-workload W01/W02/W03 benchmark has run.

## Next operation — only functional simulation

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin
git restore --source origin/main --worktree -- 01-PicoRV32/lab06
.\01-PicoRV32\tools\fetch_picorv32.ps1
.\02-NEORV32\tools\activate_ucrt64.ps1
.\01-PicoRV32\lab06\tools\run_lab062.ps1 -Mode Sim
```

Required **future**, not yet observed, results: `LAB062_SOURCE_PIN_PASS`, `LAB062_FW_IMAGE_PASS`, `LAB062_ROM_IMAGE_PASS`, `LAB062_PICORV32_UART_GPIO_TB_PASS`, `LAB062_SIM_PASS`.

The script builds a real freestanding RISC-V firmware using the operator's UCRT64 cross compiler, generates a deterministic ROM hex, stages actual CPU and UART RTL in unique ignored `_build/run_*`, runs Icarus Verilog/vvp, checks real bit-level UART and both physical LED patterns, then creates SHA manifest and receipt. Nothing is written to FPGA/Flash/SD.

After SIM PASS: create isolated Gowin FIT and STA report with correct 3.3V clock bank and compare resources **only as full native SoC**. Do not compare against old PiKoSoL+HDMI resource utilization.

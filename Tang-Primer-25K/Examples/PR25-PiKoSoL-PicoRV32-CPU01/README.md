# PiKoSoL 25K / PicoRV32 — CPU01

**DEVELOPMENT CANDIDATE — BUILD UNKNOWN / BOARD UNKNOWN. NO RELEASE.**
No tested firmware is published here. The proved fallback is **PiKoSoL Console02** (USB HID, PMOD DVI) and Tetris FIX2.

## Purpose

Demonstrate **real CPU instruction execution** on a Tang Primer 25K + Dock while retaining the physically demonstrated USB HID and DVI/HDMI hardware path unchanged. The new application overlays a small CPU-written 64x6-character area over the proven Console02 picture. The old console is retained for comparison; S1 switches USB PASSIVE/HOST, F1 switches Console/HID diagnostics.

Unlike hard-coded FPGA graphics, the string `PIKOSOL 25K / PICO RV32I CPU` must be **written at runtime by RV32I instructions** through memory-mapped I/O. HID key usage is polled by the CPU and corresponding letters/digits are echoed in a separate row.

## Source files

- `lab_top_pikosol_cpu01.sv` — unmodified USB HID / PMOD DVI / PLL and proven diagnostics inherited from Console02; CPU video overlay wiring is new.
- `pikosol_console_core.sv` — original Console02 renderer and commands, used as visual fallback.
- `pikosol_rv32i_soc.sv` — PicoRV32 interconnect, boot ROM, keyboard MMIO and 64×6 BRAM video text array.
- `cpu_boot.mem` — 83 machine-word RV32I smoke program, initialized into on-chip ROM at FPGA configuration.
- `cpu_boot_listing.S` — corresponding disassemblable source as literal `.word` values, with PC and instruction descriptions. Not a full C toolchain project yet.
- `Build_PiKoSoL_CPU01.ps1` — complete, reproducible Windows Gowin build, including pinned upstream USB HID, DVI and PicoRV32.

PicoRV32 source is fetched at **YosysHQ/picorv32** commit `ef203c2b0a3fb793280f5114941416c425c5b461`, Git blob `cc45fa998f1857b06a856ea59b931f6c37e06b34`. Original license header is preserved. All other hardware dependencies are the same pinned ones as Console02/Tetris FIX2.

## Memory map

| Region | Function |
| --- | --- |
| `0x00000000..0x000001FF` | 128×32-bit program ROM (83 words used), reset PC=0 |
| `0x10000000..0x100005FF` | 64×6 8-bit text cells, mapped as 384 32-bit CPU words |
| `0x10001000` | HID key usage code (read-only, low byte) |

No UART, no external SDRAM, no filesystem, no configuration Flash access. The first firmware does not provide a complete software shell. `HELP`, `INFO`, and `CLS` displayed by the inherited Console02 renderer are **not yet CPU-side commands**.

## Build (Windows, PowerShell 7)

Requirements: Gowin V1.9.9Beta-4 Education, Git CLI and network for exact pinned dependencies. Open PowerShell inside this project directory and run:

```powershell
.\Build_PiKoSoL_CPU01.ps1
```

The script **does not program FPGA**. It produces the bitstream, if synthesis/place/route succeeds, at

```text
%TEMP%\PR25_PIKOSOL_CPU_01\impl\pnr\pr25_pikosol_cpu01.fs
```

Only after a successful BUILD and review of `*.rpt.txt` utilization/timing reports, program **volatile SRAM**:

```powershell
.\Build_PiKoSoL_CPU01.ps1 -ProgramSRAM
```

This rebuilds, then invokes Programmer `--run 2` (SRAM). **Never writes configuration Flash.** A direct SRAM-only command with the newly built local image is:

```powershell
$fs = "$env:TEMP\PR25_PIKOSOL_CPU_01\impl\pnr\pr25_pikosol_cpu01.fs"
$programmer = "C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe"
& $programmer --device GW5A-25A --cable-index 1 --run 2 --fsFile $fs
```

## Board acceptance

1. DVI picture appears through **the exact same PMOD DVI connection** as Console02/Tetris FIX2. Do not change pin mapping or HDMI IP.
2. On S1 HOST, verify a rectangular text region near the **bottom of the 640×480 screen**: `PIKOSOL 25K / PICO RV32I CPU`. It must be CPU-written.
3. Type `A`, `B`, `1`, `2` on USB-A keyboard; verify characters appear below the banner as CPU MMIO writes.
4. Switch F1 and confirm original USB diagnostics still work. Return to the console; the CPU message should remain.
5. Record photo/video and boot-image SHA256. Check real BSRAM/logic use and Gowin timing reports.

### Known limitations

- This is a **CPU smoke test**, not yet a CPU-controlled command monitor; no full software shell or program loader.
- The boot code is a compact hand-assembled machine-word program, not a verified cross-compiled C application.
- Keyboard echoes single HID key usage and is US-uppercase; `Enter`, backspace and command history are not CPU commands yet.
- CPU boot and text content are not hardware-confirmed; FPGA resource usage and STA have not been validated.
- The `cpu_boot.mem` ROM content is independently committed alongside the machine word listing. Do not replace with an unrelated compiled `.bin`.

## Publishing policy

Do **not** merge into `main`, release `.fs` or claim BOARD PASS until successful Gowin compilation, hardware tests and video evidence. Preserve the verified Console02 firmware in its existing project folder.

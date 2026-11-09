# EX20-05.16 — Tang Nano 20K CPU-controlled HDMI (BOARD DEMO PASS)

**Hardware demonstration:** 2026-11-09. [Watch the board video](https://youtu.be/WofhTrn8Jdg).

## What works on the physical board

Operator confirmed, using an experimental **SRAM-only** FPGA image:

- VexRiscv (RISC-V, intended 48 MHz) running LiteX BIOS; interactive `litex>` over USB-UART COM25, 115200 8N1.
- HDMI picture: blue background and green rectangle on the same configured FPGA.
- CPU-side LiteX `mem_write` commands through Wishbone video MMIO change the background color, the rectangle color, and its position **without reprogramming the FPGA**.
- JTAG detected the compatible `GW2AR-18C` group (ID `0x0000081B`) using Gowin USB Cable(FT2CH), cable index 1.
- The reported implementation had positive Gowin setup (+1.885 ns) and hold (+0.321 ns) slacks *under the installed constraints*.

**Important limits:** This is a demonstrated CPU-to-video MMIO example, not a generic framebuffer, GPU, operating system, or RGB LED controller. The LiteX LED chaser and RGB LED features are deliberately disabled. Some startup UART characters appeared garbled; their meaning is not established. The two scoped PRESET setup/recovery false-path exceptions remain a **formal timing qualification**, so positive aggregate STA does not prove all excluded recovery paths. EX20-05.17 no-waiver A/B study did not complete due to a Windows BIOS linker issue. The user-confirmed board demonstration is evidence for the exercised functions only, not exhaustive reset/CDC validation.

## Source and configuration identity

| Item | Value |
| --- | --- |
| Device | Tang Nano 20K / GW2AR-LV18QN88C8/I7 |
| Integrated CPU | LiteX + VexRiscv minimal |
| Video | 1280x720 nominal @ 60 Hz / Gowin TMDS source |
| Video Wishbone base | `0xB1000000`, size 0x100 |
| Demonstrated .fs SHA-256 | `78AE2B41ACEF049F4A14AC63F74A6E595C72DABAE7EF072C142135A846F38015` |
| Video overlay source SHA-256 | `226D43CDB95675D4A35AE823FDA90639042228DB92571057D55344B0665B4623` |
| Gowin | V1.9.9Beta-4 Education |
| Programming | Gowin `programmer_cli.exe`, `--run 2` SRAM-only |
| Upstream HDMI IP | Pinned Sipeed source in `prepare_vendor.ps1`; not copied into this repository |

**Binary availability:** The exact demonstrated `project.fs` is currently on the operator's Windows build machine and has **not** been uploaded to GitHub. Do not describe this source-only publication as a downloadable, independently rebuilt release image. The recorded SHA-256 lets the operator identify the exact proven artifact. Rebuilding with different LiteX/Gowin versions does **not** guarantee the same .fs SHA-256.

## Reproduce the demonstration (already-configured image)

First verify the actual running image includes the unique video ID. In MobaXterm (COM25, 115200 8N1):

```text
mem_read 0xB1000000 4
```

Expected byte dump: `31 30 32 56` (32-bit little-endian word `0x56323031`, ASCII `V201`). **If it does not match, stop; do not write the following addresses.**

### Red background

```text
mem_write 0xB1000004 0x00FF0000
mem_write 0xB1000018 0x00000001
```

### Move the rectangle to X=600, Y=200

```text
mem_write 0xB1000008 0x00C80258
mem_write 0xB1000018 0x00000001
```

### Yellow rectangle

```text
mem_write 0xB1000010 0x00FFFF00
mem_write 0xB1000018 0x00000001
```

### Restore blue background

```text
mem_write 0xB1000004 0x00102040
mem_write 0xB1000018 0x00000001
```

Do not overlap transactions: finish each BIOS command and wait for the `litex>` prompt; for status `mem_read 0xB1000014 4`, bit 0 is BUSY. Graphics update is applied at the next accepted video frame boundary. There is no need to re-synthesize the FPGA merely to change a color or position.

## Program the known image, **SRAM only**

Close MobaXterm/other COM and JTAG tools *before running Gowin Programmer*. On our Windows machine, an open serial terminal sometimes prevented the JTAG FTDI cable from opening.

On PowerShell, first check the exact build SHA-256, then run:

```powershell
$Prog = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe'
$Fs = 'C:\GitHub\Sipeed-FPGA\Tang-Nano-20K\Examples\EX20-05-CPU-HDMI\build\gateware\impl\pnr\project.fs'
$Expected = '78AE2B41ACEF049F4A14AC63F74A6E595C72DABAE7EF072C142135A846F38015'
if ((Get-FileHash -LiteralPath $Fs -Algorithm SHA256).Hash -ne $Expected) { throw 'Unexpected .fs: STOP' }
& $Prog --scan --cable-index 1
if ($LASTEXITCODE -ne 0) { throw 'JTAG scan failed' }
# Inspect scan output: exactly one compatible GW2AR-18C device before continuing.
& $Prog --device GW2AR-18C --run 2 --fsFile $Fs --cable-index 1
if ($LASTEXITCODE -ne 0) { throw 'SRAM program failed' }
```

The command `--run 2` requests **SRAM Program**, not Flash. It replaces the running FPGA configuration temporarily. With the new image running, reopen UART COM25. After a power cycle, the pre-existing board configuration should return, as confirmed for an earlier SRAM-only HDMI test; re-check `litex>` before asserting the same result on a particular machine.

## Build from source

1. Install Gowin Education V1.9.9Beta-4, LiteX + LiteX-Boards + Migen + LiteDRAM in a compatible Python venv, and RISC-V cross-compiler for LiteX BIOS.
2. Run `prepare_vendor.ps1` to fetch the pinned official Sipeed PLL/DVI sources. They are not vendored into this GitHub tree.
3. Run `run_build.ps1 -Python <path-to-compatible-python> -Build`. This runs synthesis only; it does **not** configure FPGA.
4. Inspect source revision, generated SoC address map, PNR/STA, and build provenance before programming **any** newly built .fs. Do not assume identity with the board-demonstrated bitstream.

The source contains a local, guarded `ex20_05_sys_crg.py` shim that checks the installed LiteX-Boards CRG shape. Do not silently remove its version check to force an incompatible toolchain.

**License note:** HDMI vendor IP is fetched from upstream Sipeed using a pinned commit; consult upstream source and tool/IP licensing. Do not redistribute opaque generated vendor IP without confirmation of rights.

## Architecture

```text
PC MobaXterm / UART
        |
   LiteX BIOS / VexRiscv (48 MHz)
        |
      Wishbone bus
        |
  VIDEO_BASE = 0xB1000000
        |
  staging registers -> COMMIT -> CDC / frame-boundary latch
                                   |
                          720p pixel generator
                                   |
                           Gowin DVI/TMDS IP
                                   |
                                 HDMI
```

The system intentionally contains **one hardware rectangle and one background**, not a pixel-addressable framebuffer. `with_led_chaser=False`, `with_rgb_led=False`, and `with_buttons=False` are configuration choices for this example.

## Project status

`EX20-05.16: BOARD DEMONSTRATION PASS (CPU/UART/HDMI/MMIO)`, operator-confirmed. Additional formal CDC/reset qualification and full rebuild reproducibility remain open. Video: https://youtu.be/WofhTrn8Jdg

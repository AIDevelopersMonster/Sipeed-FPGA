# EX20-05 Stage A — Wishbone video overlay SIM PASS (2026-11-09)

**Status:** RTL source simulation PASS, operator-run Windows Icarus Verilog. **NOT** integrated RISC-V+HDMI hardware BOARD PASS.

## Reproducibility
- Board target: Sipeed Tang Nano 20K, GW2AR-18C family.
- RTL: `rtl/video_wb_overlay.v`, SystemVerilog keyword `inside` renamed to `rect_hit` in commit `53a11c17e196dd539f3136f11088f01026266910`.
- Test: `tests/tb_video_wb_overlay.v`, Windows runner: `tests/run_sim.ps1`.
- Local toolchain: `C:\msys64\ucrt64\bin\iverilog.exe`, `C:\msys64\ucrt64\bin\vvp.exe`.
- Operator ran `run_sim.ps1 -Iverilog "C:\msys64\ucrt64\bin\iverilog.exe" -Vvp "C:\msys64\ucrt64\bin\vvp.exe"`.
- Full reported output:
```text
SIM PASS EX20-05 overlay Wishbone/CDC/frame boundary
C:\GitHub\Sipeed-FPGA\Tang-Nano-20K\Examples\EX20-05-CPU-HDMI\tests\tb_video_wb_overlay.v:93: $finish called at 814000 (1ps)
EX20-05 VIDEO RTL SIM EXIT 0; inspect SIM PASS line above. No hardware writes.
```

## Testbench scope (confirmed by reported PASS)
- Wishbone identity read, full-word writes, staging, refusal to change staged state during active commit.
- Asynchronous CPU and pixel test clocks.
- State remains unchanged before frame boundary.
- Atomic frame-start update and acknowledgement propagation.
- Rectangle pixels, background pixels, inactive-video black output.
- Watchdog did not trigger.

## Limits
No FPGA configuration or Flash write occurred. This simulation alone does **not** prove full Wishbone B4 corner-case compliance, formal CDC safety, pixel timing, TMDS output, PLL closure, SDRAM, VexRiscv software execution, or integrated SoC resource/timing closure. Future work must test full end-to-end integration and hardware.

## Next gate
Build LiteX/VexRiscv SoC glue that maps this Wishbone slave at a verified **new** address, then connect HDMI raster/PLL/DVI source, synthesize for GW2AR-18C and test in FPGA SRAM only.

# LAB-03.2 — USB-UART snapshot transport for real PicoRV32 bus events

**Release candidate v0.1.0 · 20 October 2026 · Tang Nano 9K / GW1NR-9C**

**Verification:** `ASSEMBLE_PASS`, `PROTOCOL_PARSER_PASS`, and `FIRMWARE_MODEL_PASS` observed in isolated Python checks. **RTL_PENDING**, **PNR_PENDING**, **STA_PENDING**, **BOARD_PENDING**. Do **not** flash or report hardware success yet.

This stage adds a separate synthesizable SoC and ROM while preserving LAB-02 and LAB-03.1. Commands `0`–`6` and `?` retain LAB-02 behavior; new `T` outputs the last immutable trace snapshot and `C` clears/re-arms it. **Accepted fetches are not retired instructions**. Trace source is passive; the CPU drives trace MMIO reads using the ordinary bus, but trace observation never generates CPU backpressure.

- [Пошаговая инструкция RU](LAB03_2_TRACE_UART_RU.md)
- [Complete guide EN](LAB03_2_TRACE_UART_EN.md)
- [RTL SoC](../../01-PicoRV32/rtl/picorv32_soc_lab03.v)
- [Passive recorder from LAB-03.1](../../01-PicoRV32/rtl/lab03_trace_capture.v)
- [New firmware](../../01-PicoRV32/firmware/lab03_boot.S)
- [Trace decoder](../../01-PicoRV32/tools/lab03_trace_decode.py)

## Quick test on Windows PowerShell 7

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
& .\01-PicoRV32\tools\test_lab03_2.ps1 -ModelOnly
& .\01-PicoRV32\tools\test_lab03_2.ps1
```

The full test requires Python, Icarus Verilog and the pinned PicoRV32 core. **Nothing touches COM, FPGA SRAM or Flash**. An independently named Gowin build follows only after `LAB03_2_RTL_PASS`:

```powershell
& .\01-PicoRV32\tools\build_lab03_2.ps1
```

Examine `impl/pnr` reports before SRAM programming; **do not reuse the old LAB-02 `.fs`**. After programming LAB-03.2 in SRAM on the physical board, **press and release S2** before COM communication.

## UART T3 protocol v0.1

`T3:<status32>:<command32>\n`, then `count` rows `E:<index32>:<cycle_kind32>:<address32>:<value32>\n`, then `Z\n`. Fields are exactly eight hex digits each. `Z` is an end marker, **not CRC**.

`STATUS`: byte31:24=3, byte23:16=128 (capture depth); low byte=count (0..128); bits 8..12 = `done`, `truncated`, `overlap`, `timestamp_wrapped`, `capturing`. The `cycle_kind` low16 is relative cycle, high two bits in [17:16] event kind `01` fetch / `10` LED write. Other bits must be zero.

**Snapshot lifetime:** only `C` clears a completed frame; `T` is read-only. A second valid LED command before `C` still works as an LED command but does not create a new trace. UART RX during capture overlap is flagged by the existing recorder. No hidden wraparound on full memory.

**Boundary:** The protocol has strict framing and semantic validation against the LAB-03.2 ROM, but no checksum/CRC in v0.1; undetected corruption cannot be excluded. `L=n` confirms CPU MMIO readback, not optical LED brightness. This stage is not a cycle-accurate debugger nor an ISA retirement trace.

# PR25-05 UARTTX-01: standalone UART transmitter, Tang Primer 25K

**Goal:** isolate BL616 onboard debugger serial channel from complex PR25-04 USB Host firmware.

## Hardware and isolation

- Tang Primer 25K Dock / GW5A-25A / GW5A-LV25MG121NC1/I0
- FPGA 50 MHz clock: **E2** (same as Sipeed official UART demo).
- FPGA TX -> onboard debugger BL616 RX: **C3** (same as Sipeed official UART demo).
- No RX path, USB Host, RISC-V, PLL, BRAM, boot code, software, flash writes, or manual reset.
- UART 8N1; hardware TX pin idles HIGH.
- Periodic ASCII beacon **`PR25 UART TX TEST\r\n`**, roughly twice per second; 115200 baud.
- Designed to run from FPGA SRAM only via Gowin Programmer `--run 2`. Bitstream is transient; programming/restart may erase it.

## Files

- `src/top.v` -- standalone synthesizable Verilog, 19-byte message, deterministic initial state.
- `src/pins.cst` -- only E2 and C3.
- `src/timing.sdc` -- 50 MHz input timing.
- `Build_UARTTX.ps1` -- downloads all Verilog/constraints from THIS directory, builds with installed Gowin via `gw_sh.exe`.
- `Program_SRAM_UARTTX.ps1` -- programs FPGA SRAM only and prints programmer exit.
- `Probe_UARTTX.ps1` -- passively reads COM24 / COM25 at 115200 and 460800 and prints raw hex/ASCII. Close other serial terminals first.

## Commands (PowerShell 7)

```powershell
$base = 'https://raw.githubusercontent.com/AIDevelopersMonster/Sipeed-FPGA/main/Tang-Primer-25K/Examples/PR25-05-UART-TX'
Invoke-WebRequest "$base/Build_UARTTX.ps1" -OutFile C:\GitHub\Build_UARTTX.ps1
& C:\GitHub\Build_UARTTX.ps1

# ONLY after UARTTX BUILD PASS; disconnect/avoid conflicting tools:
Invoke-WebRequest "$base/Program_SRAM_UARTTX.ps1" -OutFile C:\GitHub\Program_SRAM_UARTTX.ps1
& C:\GitHub\Program_SRAM_UARTTX.ps1

# Capture. No terminal needed. If two COM ports, scan both.
Invoke-WebRequest "$base/Probe_UARTTX.ps1" -OutFile C:\GitHub\Probe_UARTTX.ps1
& C:\GitHub\Probe_UARTTX.ps1
```

## Interpretation

| Observation | Meaning |
|---|---|
| Correct `PR25 UART TX TEST` on one baud/COM | FPGA oscillator, pin C3, BL616 UART bridge and Windows COM data path are working. Proceed to repair PR25-04 if needed. |
| Correct only at host baud 460800 | Consistent with documented 4x BL616 UART baud divider bug. Fix debugger firmware separately or account for the mismatch. |
| Bytes but garbled on both settings | Wrong bridge baud/divisor, clock/timing or pin mapping. Preserve hex and compare with logic analyser or external 3.3V USB-UART if available. |
| No bytes on both ports | Incorrect COM interface, debugger UART not routing C3, SRAM programming/clock/pin problem. Compare a known-good Sipeed official UART design and external TX probe. |
| FPGA bitstream builds but programmer fails | PROGRAM FAIL, not UART failure. |

These are hypotheses, not substitute for physical measurements.

## Evidence classification

Project source created and visually reviewed; not locally synthesized/simulated because the operator's Gowin is installed on Windows. The initial physical build/program/COM results are **OPEN**. Do not mark PASS based on project generation alone.

## Pin provenance

Official Sipeed Tang Primer 25K UART example: https://github.com/sipeed/TangPrimer-25K-example/blob/main/UART/simple_uart/src/top.cst .

## Follow-up

After this small lab produces known ASCII, return to PR25-04 USBH01 and isolate any CPU/BRAM/USB issue. Do not conflate correct UART beacon with validated USB Host or HID keyboard.

## 2026-11-14 physical UART test

Operator supplied captured evidence: `SRAM PROGRAM EXIT: 0`, COM24 at 115200 and 460800 yielded **zero bytes**; COM25 at 115200 yielded 3032 bytes, including **97 complete ASCII `PR25 UART TX TEST\\r\\n` records** in two uninterrupted groups of 87 and 10, with additional non-ASCII/garbled data before/between; COM25 at 460800 yielded 415 bytes with **one complete ASCII record**, plus garbled data. Thus **FPGA->C3->BL616->Windows COM25: periodic known text physically verified on 115200**. Do not claim USB Host or RX PASS. Because the serial capture was sequential after opening baud 460800, earlier garbled bytes may be buffered/cross-baud transitions; a stable clean 115200 capture after reconnect is an optional follow-up. USBH01 diagnostic should begin with COM25 already open before SRAM programming to catch one-time firmware boot messages.

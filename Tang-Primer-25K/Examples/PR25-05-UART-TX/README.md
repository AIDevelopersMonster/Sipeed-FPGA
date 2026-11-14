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

## Physical result: 2026-11-14 UARTTX PASS with mixed/garbled blocks

User ran SRAM programming and the passive serial diagnostic. Evidence pasted in chat:

- `SRAM PROGRAM EXIT: 0`.
- Host-visible serial ports `COM1, COM24, COM25`.
- `COM24` returned no bytes at 115200 or 460800.
- `COM25` at **115200** returned **3032 bytes** including **97 exact repetitions** of `PR25 UART TX TEST\r\n`; also long irregular regions of `00 78 80 F8`-patterned garbage. This establishes a working C3->debugger->COM25 path at least for substantial intervals, not a fully clean UART channel.
- `COM25` at 460800 returned **415 bytes**, only one intact expected line and predominantly garbage; 460800 is **not** the preferred setting on this specimen with current firmware.
- Interpretation: the proper test UART receive setting is currently COM25 / 115200, but invalid bytes and unexpected burst structure remain to investigate. The 97 repetitions in a 5-second read and long runs of contiguous 19-byte frames warrant caution: the apparent timing does not match an uninterrupted beacon with a 0.5-second inter-message pause, suggesting buffer/backlog, alternate data path or UART instability. Do NOT declare clean UART PASS or stable BL616 divisor from this experiment.

Next: with no serial probe open, program PR25-04 USBH01 while a separate COM25/115200 capture is already open; record raw bytes from boot and attach a wired USB-A keyboard. `Capture_USBH01.ps1` is in PR25-04 to orchestrate this. If no meaningful RISC-V boot banner, investigate memory initialization `mem.hex`, reset/PLL, and USBH01 TX path rather than changing serial baud randomly.

## 2026-11-14 UART terminal baud adjusted: clean text

After prior captures showed alternating valid ASCII `PR25 UART TX TEST` frames and deterministic garbled UART bytes, the operator reported: **"После выставления правильной скорости у меня нормально показывает терминал"** — after selecting the correct serial baud setting the interactive terminal displays the beacon normally. The **exact selected terminal baud rate was not supplied**; do not assume 115200 or 460800. This is direct functional evidence for a readable FPGA C3 → BL616 → Windows COM terminal link at the chosen rate, in addition to the prior SRAM programming PASS.

**Evidence status:** UART-TX functional PASS in terminal at corrected baud setting (exact baud and prolonged stability not yet logged); RX path NOT tested; USB Host/USB-A keyboard/HID NOT tested. Next restore the existing `PR25-04-USBHost-UART` bitstream via FPGA SRAM only, capture `COM25` at the actual *working* host-side baud rate, and check the original firmware boot messages first, then boot-keyboard enumeration directly on the Dock's USB-A connector, finally optional external USB hub. The host firmware's UART divider targets ~115200 baud physically and changing the host COM baud on BL616 might not correspond to the physical baud if the debugger firmware has a divider defect.

## 2026-11-14: 9600 baud next test

Operator requested reducing the standalone TX UART baud to **9600** after seeing initial garbage on terminal attach. The most recent 10-second COM25 capture at **115200 8N1** returned **1805 bytes**, precisely **95 complete copies** of the expected 19-byte `PR25 UART TX TEST\r\n` line, with no non-frame bytes; this independently confirms a clean captured byte stream in that test window. The user's terminal still displays occasional garbage at attachment/start, which was not reproduced in that 10-second programmatic capture. Do not interpret the 1805-byte capture as evidence of current persistent corruption.

Updated `src/top.v` default `BAUD_RATE` from 115200 to 9600, and the CLI build's printed expectation to 9600. **A fresh FPGA bitstream build and SRAM download are required**: the previously built .fs remains 115200. The actual bit-clock divider with 50 MHz clock is `round(50,000,000/9,600)=5208`, yielding about 9600.6 baud. Keep COM25 at **9600 8N1**, none flow control for first trial. Only if capture is garbled may a debugger UART baud-divisor issue motivate further testing; do not assume the BL616 firmware version or rate ratio.

Technical caveat: 95 complete frames in ten seconds differs from the intended ~0.5-second inter-message delay. The source `src/top.v` uses a 25,000,000-cycle gap at `char_index==0`. Actual observed cadence must be measured independently (COM output counts alone may reflect buffering or a different clock). This does not prevent testing byte integrity at 9600.

Suggested PowerShell:

```powershell
$base='https://raw.githubusercontent.com/AIDevelopersMonster/Sipeed-FPGA/main/Tang-Primer-25K/Examples/PR25-05-UART-TX'
Invoke-WebRequest "$base/Build_UARTTX.ps1" -OutFile 'C:\GitHub\Build_UARTTX.ps1'
& 'C:\GitHub\Build_UARTTX.ps1'
# Check UARTTX BUILD PASS before replacing running SRAM design.
& 'C:\GitHub\Program_SRAM_UARTTX.ps1'
& 'C:\GitHub\Probe_UARTTX.ps1' -Ports COM25 -Bauds 9600 -Seconds 10
```

The external USB Hub / USB Host work remains parked until this UART diagnosis completes; no Flash changes.

## 2026-11-14 9600-baud build and hardware capture

User uploaded Gowin/Programmer/COM log for the new 9600-baud build:

- Gowin CLI `EXIT 0`; synthesis/placement/routing/timing analysis and bitstream generation completed; expected FS SHA256 `DA042C80F4D68D0B61C86AFA4641C932641C30213AE94584DF004880C7FE4CA1`.
- Programmer target `GW5A-25A`, JTAG ID `0x0001281B`, operation `SRAM Program` 100%, `SRAM PROGRAM EXIT: 0`.
- COM25 at 9600 8N1 captured **5152 bytes during 10-second read**. Most data consists of intact `PR25 UART TX TEST\\r\\n` frames, but one interruption contains a truncated frame and a run of zero bytes (raw sequence `...50523250 50523235... 0000...`). **9600 does not eliminate the anomaly.** An intact message is 19 bytes, and 5152 bytes correspond to >270 message lengths, far more than the ~19 expected frames in 10 seconds from `GAP_CYCLES=25000000` and 50MHz clock.
- No precise timestamp for individual bytes was collected; a receive-buffer backlog, BL616 USB bridge behavior, actual FPGA output timing, and tool-reporting issues remain separate hypotheses. Do not equate observation with proof of an FPGA clock/CDC failure.

**Clock-domain audit:** PR25-05 `top.v` has only `posedge clk_50m`, no PLL or internal CDC. Asynchronous UART reception occurs in the external BL616/USB interface. A PR25-04 USB Host CDC review remains relevant separately (48/96 MHz PLL and BRAM phase alignment).

New reproducible controls: [Capture_UART_Stable.ps1](./Capture_UART_Stable.ps1) opens COM25 once at user-selected rate, settles, flushes Windows receive buffer and timestamps complete messages. Separate [PR25-06 UART-IDLE](../PR25-06-UART-IDLE/README.md) drives C3 permanently HIGH with no clock, CDC or UART transmit state; any *newly* reported serial bytes after flushing its input cannot originate from that RTL. These are diagnostic experiments, **not hardware PASS** yet.

## PR25-05 bounded packet mode

2026-11-14: Per operator instruction, use **fixed packet size, transmit-complete gating, and no new packet before the previous packet is fully sent**, rather than implementing request/ACK protocol for this simple test. Current `src/top.v` is a single-clock FSM: `ST_GAP -> ST_LOAD -> ST_SEND -> ST_GAP` and `ST_DONE` on completion. **The full final stop bit** of the final byte must finish before `packets_completed` increments or another packet can be scheduled. No FIFOs, packet overlaps or CDC. Defaults: `PACKET_BYTES=19` (ASCII `PR25 UART TX TEST\r\n`), `MAX_PACKETS=16` after FPGA configuration (total `304` bytes maximum), `BAUD_RATE=9600`, `CLOCK_HZ=50000000`, `GAP_CYCLES=25000000` (~500ms between packets). After the 16th packet, TX stays HIGH until a new FPGA SRAM configuration. This is **not** external BL616 flow control; it constrains only the FPGA source. Previous unbounded build SHA256 `DA042C80F4D68D0B61C86AFA4641C932641C30213AE94584DF004880C7FE4CA1` is not the new bounded bitstream.

**Board procedure:** close the COM terminal; open COM25 at 9600 baud/8N1 before SRAM programming if possible, because this is a **finite** 16-packet transmission; run `Build_UARTTX.ps1` then `Program_SRAM_UARTTX.ps1` (SRAM only). The first packet begins approximately 0.5 seconds after configuration, and all 16 take roughly 8.3 seconds. `Probe_UARTTX.ps1 -Ports COM25 -Bauds 9600 -Seconds 12` can capture only if active by the time packets transmit. For deterministic one-run automation, start a receive program before programming in a separate terminal, or run a new FPGA SRAM program while COM25 is already open; if the receiver is opened after programming, earlier packets may already have been emitted and the full 16 are not guaranteed to appear.

**PASS criteria:** at most 16 fresh exact packets per configuration, no overlap, correct stop bits/line idle and expected ~0.52s inter-packet period; any extra bytes after the FPGA finishes indicate downstream buffering or corruption and must be independently isolated. Source reviewed; FPGA/Gowin synthesis and board PASS for this new bounded revision remain OPEN.

## 2026-11-14 repeated SRAM programming: bounded TX hardware PASS (304+1)

The operator repeated FPGA SRAM programming / startup, then captured 20 seconds of `COM25 @ 9600 baud, 8N1` with the bounded `PACKET_BYTES=19, MAX_PACKETS=16` RTL. Complete results:

- `RESULT: 305 bytes`.
- Raw HEX begins `00 50 52 32 35 20 55 41 52 54 20 54 58 20 54 45 53 54 0D 0A...`.
- Bytes 1..304 are **exactly 16 consecutive copies** of 19-byte `PR25 UART TX TEST\r\n`, with zero missing, extra, or overlapping packets and no continuing stream.
- One extra **leading 0x00** is present in the receive stream (byte 0). This may be a UART framing event during FPGA SRAM reconfiguration, I/O tri-state/idle transition, BL616 UART RX handling, or buffered artifact. This observation alone does not prove an internal RTL reset or CDC issue.

**Classification: UART TX bounded-packet hardware PASS at COM25 9600 8N1, with one startup anomaly (leading 0x00), not an entirely clean link.** The transmitter has one 50MHz domain; no internal CDC in PR25-05. External BL616 receiver is asynchronous as standard UART. Next, if needed, isolate the startup zero by opening COM25 **before** SRAM reprogram and timestamping bytes, and consider pull-up/buffer initialization on C3/BL616 RX during configuration. Preserve the working 9600 firmware. Do not alter Flash. USB Host, processor, and UART RX remain unverified.

# LAB-03.2 — UART transport for a real PicoRV32 bus snapshot

**Stage:** v0.1.0, 20 October 2026 · **Target:** Sipeed Tang Nano 9K / GW1NR-9C.

**Verified so far:** dedicated ROM assembly (202 RV32I words, 1024 B ROM); Python T3 protocol parser negative tests; Python firmware execution model for `C → 4 → T → T → C → 1 → T`. **RTL_PENDING · PNR_PENDING · STA_PENDING · BOARD_PENDING.** These are independent model checks, not FPGA tests.

## Architecture

LAB-03.2 isolates all new hardware from the proven LAB-02: `picorv32_soc_lab03`, `lab03_boot_rom.v`, `firmware/lab03_boot.S` and `gowin_lab03_2_build.tcl` (producing a distinct `picorv32_lab03_nano9k.fs`). The earlier `lab03_trace_capture.v` remains unchanged and passively records accepted bus fetches and LED MMIO writes. The CPU accesses the 128-event snapshot through additional MMIO addresses. No UART trace output is transmitted asynchronously during CPU operation: `T` is a firmware command and uses the ordinary CPU-driven UART TX peripheral.

Trace MMIO offsets from `0x20000000` are `0x20` STATUS, `0x24` COMMAND, `0x28` INDEX, `0x2C` META, `0x30` ADDRESS, `0x34` VALUE and `0x38` CLEAR. Writing INDEX initiates a synchronous RAM read; the CPU's later LOAD instructions read the held values. The capture RAM is 128 × 82 bits; it never wraps silently. `T` returns a frozen snapshot; `C` explicitly clears and rearms it. A subsequent LED command without `C` operates normally but cannot replace the existing finished snapshot.

## ASCII wire protocol v0.1

The board accepts ordinary LAB-02 single-character commands `0`–`6` and `?`, responding `L=n\n`. New commands are `C` (clear/rearm, reply `C\n`) and `T` (trace readout). A trace consists of:

```text
T3:<8-digit hex STATUS>:<8-digit hex COMMAND>
E:<8-digit hex INDEX>:<8-digit hex CYCLE_KIND>:<8-digit hex ADDRESS>:<8-digit hex VALUE>
...
Z
```

STATUS `[31:24]=3`, `[23:16]=128`, `[12]=capturing`, `[11]=timestamp_wrapped`, `[10]=overlap`, `[9]=truncated`, `[8]=done`, `[7:0]=count`. CYCLE_KIND `[17:16]` is kind `1=FETCH / 2=LED_WRITE`, `[15:0]` is the relative timestamp. Each accepted FETCH word is checked against the dedicated `lab03_boot.hex`; the last event of a complete capture must be one accepted LED MMIO write to `0x20000000` with the correct mask.

`Z` is a delimiter, **not** a checksum. Strict parsing catches malformed or missing fields and ROM mismatches, but there is **no CRC** in this protocol version. **FETCH is an acknowledged instruction read, not retirement/commit**, and LED MMIO readback is not optical measurement.

## Repeat with Windows PowerShell 7

Install from the supplied archive using `Install-LAB03_2.ps1` while on the `feature/picorv32-lab03-trace-recorder` branch at commit `c977184`; the installer creates a new `feature/picorv32-lab03-uart-trace` branch and preserves local unrelated files and the LAB-02 ROM. Then:

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
& .\01-PicoRV32\tools\test_lab03_2.ps1 -ModelOnly
& .\01-PicoRV32\tools\fetch_picorv32.ps1
& .\01-PicoRV32\tools\test_lab03_2.ps1
```

The complete script invokes Icarus Verilog using the real PicoRV32 + dedicated ROM and traces UART output through a separate RTL receiver. It compares two successive `T` reads byte-for-byte and validates both original command `4` and subsequent rearmed command `1`. **Only after actual `LAB03_2_RTL_PASS`** run the distinct Gowin build:

```powershell
& .\01-PicoRV32\tools\build_lab03_2.ps1
```

Inspect PnR, Fmax and setup/hold STA before configuring *volatile SRAM only* with the LAB-03.2 bitstream (not the LAB-02 bitstream). **Press and release the physical S2 button after SRAM programming and before UART communication.**

After the new bitstream is configured and the browser releases COM:

```powershell
& .\01-PicoRV32\tools\probe_lab03_2_serial.ps1 -PortName COM10 -CaptureNew -Led 4
```

The physical probe sends `C, 4, T`, writes the trace to a timestamped file in `build/`, closes the COM port in `finally`, and checks the real ROM words. Observe the physical LED separately. **BOARD_PASS has not yet been established.**

**Research experiment:** A. A. Malachevsky, ORCID 0009-0008-6009-3196. **Upstream CPU:** PicoRV32 by Claire Xenia Wolf, ISC. Original lab content MIT.

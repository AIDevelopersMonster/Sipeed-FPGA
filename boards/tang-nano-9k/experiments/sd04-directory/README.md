# SD-04 — ROOT sector read-only bridge (development)

Separate experiment; SD-01/02/03 and PiKoSoL v0.2.0 are unchanged.

Goal: use proven SD-03 MBR/VBR detection, then CMD17 on its computed
root directory LBA, output exactly 1024 uppercase ASCII hex characters plus
CRLF at 115200 8N1. Python decodes FAT32 directory records (16 entries per sector).
On scanner/reader failure returns ERROR CRLF, never a fabricated directory.

**Status:** unverified RTL candidate, NOT hardware PASS. No SD writes, no CMD24.

Source dependencies are referenced from the frozen SD-03 snapshot rather than
copied. Run Gowin PnR and inspect setup/hold and external SD MISO timing before
SRAM-only board test. A standalone Python reader follows after a successful
simulation gate.

## Host-only decoder (no card writes)

After the UART reader is independently hardware-qualified and its complete
line has been captured to `root.hex`:

```powershell
python -m unittest discover -s .\boards\tang-nano-9k\experiments\sd04-directory\tests -p "test_*.py"
python .\boards\tang-nano-9k\experiments\sd04-directory\tools\sd04_decode.py .\root.hex --sector-out .\root.bin
```

Frame is 1024 ASCII uppercase HEX digits followed by CRLF, or `ERROR` CRLF.
This prototype reports only the FIRST root sector: it does not follow FAT
chains, scan later sectors, or claim a complete directory. Verify raw sector
against PC read-only capture, then add CRC/protocol framing and error detail
before general-purpose use.

## Important qualification gates

1. Python unit tests; Verilog RTL simulation and 512-byte UART framing test
   must be added and passed before hardware.
2. Run Gowin synthesis/PnR/STA with the exact `build.tcl` dependencies and
   explicitly review setup/hold plus external MISO timings.
3. Compare source hashes of the referenced SD-03 RTL; no silent modifications.
4. FPGA SRAM-only test; capture actual UART and compare all 512 bytes against
   host extraction. No physical PASS is claimed at this revision.

Note: `build.tcl` is the Gowin project recipe; no automated build/program
script or hardware receipt is supplied yet.

## Reproducible local verification

From the repository root, with Python and Icarus Verilog installed:

```powershell
& .\boards\tang-nano-9k\experiments\sd04-directory\test.ps1
```

This checks Python decoding, a complete RTL dependency compile and a synthetic 512-byte UART transport test. It does not establish physical SD behaviour, PnR timing, or hardware readiness. Run Gowin STA separately before programming SRAM.

## SD-04 Gowin PnR/STA candidate

After `SD04_LOCAL_GATE_PASS`, run **build-only** from PowerShell 7:

```powershell
& .\boards\tang-nano-9k\experiments\sd04-directory\build.ps1
```

`build.ps1` reruns the simulation gate, stages frozen SD-03 RTL and constraints together with SD-04 top into a unique ignored `build/run_*/work` tree, writes `input_sha256.csv`, executes `gw_sh.exe`, and reports the resulting `.fs` SHA-256 and paths to PnR/STA files. It **never programs SRAM or Flash**, and never writes an SD card. No new Gowin result is certified merely by generating `.fs`. Confirm numerical setup/hold violations and timing scope before a physical test.

The prior local acceptance from the operator was `SD04_ROOT_DUMP_TB_PASS` and `SD04_LOCAL_GATE_PASS` (simulation only). PnR/STA and hardware acceptance remain unverified.

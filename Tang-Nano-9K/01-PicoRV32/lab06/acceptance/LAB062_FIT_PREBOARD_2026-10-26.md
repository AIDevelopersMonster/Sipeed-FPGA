# LAB-06.2B — PicoRV32 exact FIT and read-only pre-board decision

**Date:** 2026-10-26. **Evidence:** operator-provided PowerShell console logs, from `fit_lab062.ps1` and `diagnose_fit_lab062.py`; not independent access to local Gowin reports.

**Evidence classification:** SIM PASS (validated by fit script); Gowin PnR PASS; Setup/Hold preliminary PASS; 10/10 fitted I/O and VCCIO PASS; Recovery/Removal **NO REPORTED PATHS**, hence FULL STA/ASYNC RESET RELEASE **NOT QUALIFIED**. Exact candidate eligible only for one bounded volatile-SRAM-only board smoke, not Flash, production release or blanket STA sign-off. Board **NOT RUN**.

## Identity and source

- Project: `01-PicoRV32/lab06`; original CPU pin `ef203c2b0a3fb793280f5114941416c425c5b461` (ISC).
- Simulation receipt: `_build/run_20261026_174737_806/receipt.json` (operator FIT verified `Simulation=PASS` plus UART/GPIO TB marker).
- 16KiB ROM hash: `694CF644C770382518371DF4382013AAFEDB6CFEEFC87F6CA15A140BA2F2478B`; original RV32I binary 140B hash `6AB802C371F1100F40635019C4306B44DF04E572B51F0070DA4C9AA0808415F6`; 2KiB RAM; 27MHz, UART 115200 8N1.
- Exact PnR directory: `_build/fit_20261026_174759_839_3ed614`.
- **Bitstream SHA256:** `31691075B56BB4167758AEB9D99CE8E7F4CE0BE84333D527FD2659606025F4A0`.

## Observed timing

- Analyzed paths `1794`; endpoints `1530`; setup/hold violation counts `0/0`.
- Minimum Setup `+16.325ns`, Hold `+0.427ns`.
- `clk_i`: 37.037ns, 27.000MHz; PnR-estimated Fmax `48.281MHz`; **not** a tested hardware frequency.
- For both `Recovery Paths Table` and `Removal Paths Table`, Gowin output is literally `Nothing to report!`. Violated endpoint counts are `NOT_REPORTED`, **not zero**. These sections do **not** certify timing of asynchronous reset release on external S1 (the RTL has async reset pins). A clock-only SDC has no external UART RX or reset release input timing characterization.
- Gowin documentation: [Design Timing Constraints, SUG940](https://cdn.gowinsemi.com.cn/SUG940E.pdf); `Nothing to report!` means no timing path in the corresponding analysis category.

## Observed fitted I/O

| Port group | FPGA pins | IO type | BankVccio | Status |
| --- | --- | --- | --- | --- |
| `clk_i` | 52 / Bank1 | LVCMOS33 | 3.3 | MATCH |
| `uart0_txd_o`, `uart0_rxd_i` | 17,18 / Bank2 | LVCMOS33 | 3.3 | MATCH |
| `rstn_i` | 3 / Bank3 | LVCMOS18 | 1.8 | MATCH |
| `led_n_o[0..5]` | 10,11,13,14,15,16 / Bank3 | LVCMOS18 | 1.8 | MATCH |

All ten port rows have `Constraint=Y`.

## Measured resources, not core-only area

- Logic `1500/8640 (18%)`.
- Register `551/6693 (9%)`.
- BSRAM `54%` (the shown resource summary also lists `SDPB 2`).
- DSP 0; PLL 0/2; IO 10.

This is the **whole PicoRV32 native minimal SoC**, not just CPU. The corresponding NEORV32 build reports Logic 3228/8640 (38%), Register 1923/6693 (29%), BSRAM 20%. Do **not** conclude the same RAM/ROM primitives or that CPU alone uses 54% BSRAM; memory inference remains to be audited. W01/W02/W03 performance comparison still NOT RUN.

## One-time volatile SRAM smoke — bounded risk accepted for development only

The constrained 27MHz data paths, exact SHA, and fitted I/O voltage/pin checks are positive. However, reset deassertion has not been timing-certified. For the **existing simple Tang Nano 9K lab board** it is reasonable to perform one time-boxed *SRAM-only* UART/LED hardware smoke, explicitly treating S1 reset response as an observed test rather than guaranteed safety.

- Use the exact SHA-verified bitstream above and existing `01-PicoRV32/lab04/tools/program_lab04_sram.ps1`, with default dry-run first. Opt in to `-Program` only after hash confirmation.
- Its operation index 2 means **volatile SRAM**, no configuration Flash or SD write.
- Expect `PICORV32 READY\r\n` (16 bytes) and final GPIO `0x2A` (3 alternating physical LEDs).
- Record programmer output, COM capture, LED observation and reset behavior.
- If failures persist after 2–3 documented checks, stop and diagnose reset synchronization, COM, power, and physical connections; do not begin uncontrolled rebuilds.
- **Not claimed:** Recovery/Removal slack PASS, asynchronous reset sign-off, UART RX timing qualification, reset reliability, full CPU ISA compliance, equal-workload CPU speed.

**Status at writing:** FPGA board NOT RUN, and no FPGA/Flash/SD action has been carried out by these audit scripts.

## Hardware attempt — 2026-10-26: USB/JTAG cable open failure (no SRAM programming)

This update supersedes the earlier "Board NOT RUN" time marker with an **attempt**, not a hardware pass. Operator performed a SHA-verified dry-run of `01-PicoRV32/lab04/tools/program_lab04_sram.ps1 -Bitstream $Fs`, which passed without touching FPGA. Operator then invoked `-Program` once (same SHA) and received:

```text
Target Cable: Gowin USB Cable(FT2CH)/0/0/null@2.5MHz
Target Device: GW1NR-9C(0x1100481B)
Operation "SRAM Program" for device#1...
Error: Cable open failed
Cost 0.0 second(s)
Gowin Programmer failed with exit code 50
```

No progress bar or SRAM write occurred, and there was no Flash/SD action. This is a **USB/JTAG access failure**, not a fail of logic/CPU/STA/bitstream identity; physical CPU boot/UART/GPIO are still **NOT TESTED**. The reported device name can be the requested device target rather than proof of detection because the cable was not opened.

Next only two bounded steps: (1) inspect/release FTDI COM/JTAG ownership; (2) read-only `programmer_cli.exe --scan --cable-index 1`, one retry of exact SRAM load only after a positive scan. If repeated, stop and diagnose driver A/B and cable/USB power before any firmware changes. Earlier NEORV32 SRAM programming on the same board succeeded. See [Sipeed cable-open FAQ](https://wiki.sipeed.com/hardware/en/tang/common-doc/questions.html).

**Updated status:** PnR verified; hardware load **CABLE_OPEN_FAILED, NOT CONFIGURED**; no board UART/LED result; preliminary STA and async reset caveats unchanged.

## 2026-10-27 — successful USB/JTAG access, but different bitstream

Operator subsequently ran the SRAM programmer again. This time the actual `BITSTREAM:` was **KonSol-RetroStation KBlocks**, not the Pico candidate:

```text
BITSTREAM: C:\GitHub\KonSol-RetroStation\games\kblocks-rgb\build\20261026_125847\work\impl\pnr\konsol_kblocks_rgb_nano9k.fs
SHA256: F842B196CB4A56E0C18DEF1C471CBDDC82F59F0B552A27F553FDFF9692BBDC4E
OPERATION: GW1NR-9C, operation_index 2, volatile SRAM (not Flash)
Target Cable: Gowin USB Cable(FT2CH)/0/0/null@2.5MHz
Target Device: GW1NR-9C(0x1100481B)
Operation "SRAM Program" for device#1...
Programming...: [#########################] 100%
User Code: 0x0000F9C8
Status Code: 0x0003F020
Cost 3.65 second(s)
LAB04_SRAM_PROGRAM_COMMAND_PASS
```

**Evidence interpretation:** USB/JTAG and SRAM programming are functional for the KBlocks image; the earlier `Cable open failed` is not shown to be a permanent programming-cable defect. But the PowerShell `$Fs` variable was **pointing to a RetroStation image**: no successful Pico LAB-06.2 programming or physical UART/GPIO check has been reported. Pico remains **BOARD NOT RUN / NOT LOADED**. Do not merge a KBlocks success into Pico acceptance.

The Pico image remains SHA256 `31691075B56BB4167758AEB9D99CE8E7F4CE0BE84333D527FD2659606025F4A0`; next use a separate `$PicoFs` variable with full SHA and filename verification, then a single volatile-SRAM test. Original Gowin async-reset recovery/removal caveat still applies.

# PiKoSoL LAB-04.2 v0.1.6a: CDC STA correction (candidate)

**Finding (user Gowin 22 Oct 2026 22:20):** CPU+HDMI v0.1.6 has 7 setup
violations on new 27 MHz to 25.2 MHz LED CDC paths, worst -0.334 ns.
These are the request synchronizer input and six bundled-data mailbox bits;
the hold/recovery/removal paths are positive. The reported 'TNS=0' for
individual clocks DOES NOT override the explicit 7 violated endpoints.

## Fix

- The original `constraints/lab04_video.sdc` remains byte-for-byte unchanged.
- `build_scripts/gowin_lab04_smoke.tcl` remains unchanged.
- CPU builds now select `constraints/lab04_cpu_video_v016a.sdc` (exactly
  one SDC per Gowin build), copying the original three SVO max-delay rules
  and adding eight **point-to-point** 12 ns bounded CDC rules:
  request to first sync stage, each of six stable data bits to destination
  capture FF, acknowledgement to first sync stage.
- No `set_false_path`, global async clock groups, RTL, ROM, PLL, TMDS or reset
  logic modifications. These constraints describe the existing handshake,
  **they do not repair a broken CDC** or prove metastability MTBF.
- `tools/check_sta_v016a.py` rejects any report with setup/hold violations,
  nonpositive minimum setup/hold/recovery/removal or a missing/inactive new
  constraint or missing matching physical path; checks all 8 separately.

## Steps on Windows (repository root)

First run the installer **without** `-Apply`, then with `-Apply`.
The installer makes backup copies of changed files in ignored
`lab04/build/sta_v016a_backup_*`. It does not run Gowin or program hardware.

```powershell
cd C:\GitHub\Sipeed-FPGA
python .\01-PicoRV32\lab04\tools\verify_kit.py
& .\01-PicoRV32\lab04\tools\test_lab04.ps1 -ModelOnly
& .\01-PicoRV32\lab04\tools\test_lab04.ps1
& .\01-PicoRV32\lab04\tools\build_lab04.ps1 -Mode CPU
```

Set `$Job` to the **new** `cpu_*` build folder printed in `LAB04_ISOLATED_BUILD_DIR`.
Run report gate (not against the old v0.1.6 reports):

```powershell
$Report = Join-Path $Job 'work\impl\pnr\picorv32_lab04_hdmi_nano9k_tr_content.html'
$Log = Join-Path $Job 'gowin_cli.log'
python .\01-PicoRV32\lab04\tools\check_sta_v016a.py $Report --log $Log
```

Do not program unless the gate prints `LAB04_V016A_STA_REPORT_GATE_PASS` and
RTL tests pass. No false implication that CLI bitstream success proves timing.
Remember: `programmer_cli --operation_index 2` programs **SRAM only**;
operation 4 can return `Verify Failed` on this board.

**Not verified in this package:** running Gowin or physical hardware. The
SDC exact names were derived from the supplied v0.1.6 routed timing report;
re-run Gowin and check the actual exception blocks and slacks.

# LAB-03 · PicoRV32 Bus Trace Observatory — teaching interface v1.1.0

A local, dependency-free browser interface for **observing saved real-FPGA bus traces** from the Tang Nano 9K LAB-03 series. Includes the original unmodified LAB03_3_EVIDENCE.zip archive plus 12 T3 ASCII captures (six command `0`, six command `4`), with 269 accepted instruction FETCH events and 12 final LED MMIO writes. The page performs SHA-256 validation of the bundled raw dumps and the exact LAB-03 ROM (`14b85bc2…b5b8a3d`).

## Start on Windows PowerShell

**Version 1.1.0 is already published on the `feature/picorv32-lab03-uart-trace` branch.** A new student can clone that branch and run the launcher without extracting any ZIP. The ZIP overlay shown below is intended for updating an existing offline installation. See `methodics/INSTALL_RUN_RU.md` for the clean-clone route.

```powershell
cd C:\GitHub\Sipeed-FPGA
Expand-Archive "$HOME\Downloads\LAB03_Observatory_v1.1.0.zip" -DestinationPath . -Force
python .\docs\lab03\observatory\tests\verify_observatory.py
& .\01-PicoRV32\tools\launch_lab03_observatory.ps1
```

Open `http://127.0.0.1:8765/`. Requires Python 3; Chromium/Edge for Web Serial. All external dependencies are avoided.

Five interface areas: **Trace Explorer**, **Trace Comparison**, **RV32I Instructions**, **Student Worksheet** (Markdown export), **Terminology / T3 Protocol**. Playback replays recorded bus events, not hardware timing. The board can be explicitly opened through Web Serial and queried with one-byte `C`, command `0`..`6`, `T` protocol; data must match strict T3 framing and expected ROM.

The comparison view starts with **board-versus-board** only. To test RTL↔FPGA, upload actual Icarus-produced dumps `lab03_4_trace_0.txt` and/or `lab03_2_trace_4.txt`. Browser cannot verify the provenance of an uploaded RTL file.

**Scope:** accepted instruction-read bus events are *not* retired instructions; cycle counts are not compared; LED indicators show stored logical MMIO mask, not a physical optical reading; programmed FPGA SRAM has not been independently read back. No programming tools, USB drivers or configuration flash are touched by the observatory.

Offline data audit: `python docs/lab03/observatory/tests/verify_observatory.py`. Optional Node.js 22+: `node --test docs/lab03/observatory/tests/trace-core.test.mjs` and `node --test docs/lab03/observatory/tests/ui-smoke.test.mjs` (mock serial, not board).

Note: the `boot.hex` included inside the historical campaign archive is a stale LAB-02 reference. Observatory uses the verified LAB-03 `data/lab03_boot.hex` instead.

## v1.0.1 - asset delivery and inline styling fallback

The original CSS remains in `src/styles.css` and is embedded byte-for-byte in
`index.html` for fail-safe presentation if the browser cannot fetch the external
stylesheet. The local server checks `asset-manifest.json` SHA-256 entries before
startup and refuses missing or corrupt CSS, JS, ROM or evidence. For diagnosis:

```powershell
& .\01-PicoRV32\tools\launch_lab03_observatory.ps1 -CheckOnly
python .\docs\lab03\observatory\tests\test_asset_delivery.py
```

The HTTP delivery smoke test is not a real COM or full browser acceptance test.

## v1.1.0 — measured-instruction explorer and Russian lab manuals

A new **03 RV32I Instructions** tab extracts only the instruction mnemonics that
actually occur in the 12 archived accepted FETCH records (**6**: addi, andi, beq,
jal, lw, sw) or in the pinned active LAB-03 ROM (**10**, additionally lui, bne,
srli, jalr). The 54 trailing ROM padding NOP words are shown separately.
Each entry contains the original PC, 32-bit machine word, syntax, operands,
ISA effect, actual project usage and navigation to a captured event where available.
FETCH is not architectural retirement.

Russian student/instructor manuals are included under `methodics/`:
`LAB03_METHODICAL_RU.md`, `INSTALL_RUN_RU.md`, `ISA_REAL_DATA_RU.md`,
`STUDENT_REPORT_TEMPLATE_RU.md`, `TEACHER_GUIDE_RU.md`.
Use the **complete** `LAB03_Observatory_v1.1.0.zip` overlay, check assets with
`launch_lab03_observatory.ps1 -CheckOnly`, and open `http://127.0.0.1:8765/`.

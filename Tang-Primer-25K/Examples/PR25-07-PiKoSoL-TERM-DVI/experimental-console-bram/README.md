# PiKoSoL Primer 25K — BRAM console integration candidate

**Status: UNTESTED / DEVELOPMENT BRANCH ONLY.** Not a publication, not a bitstream, not BOARD PASS.

## Why this exists

The operator's local `PR25-PiKoSoL-Console01-TEST` build failed at Gowin synthesis:
`IF0008: The number(32768) of DFF used to infer "vram" exceeds ... (23280)`.
The local `pikosol_console_core.sv` declares `logic [7:0] vram [0:2399]`, writes in separate clear/edit paths at lines 466, 531 and 535, and reads at line 584. The exact full Console01 source is **not in this GitHub repository**. Do not pretend this module is already integrated with Console01.

## Source and isolated test

- `pikosol_vram_80x30.sv`: 2400 x 8-bit storage, one synchronous write port and one registered read port. No full-array reset; clears must be serialized through write interface. A block-RAM synthesis attribute is a *hint*, not proof of BSRAM mapping.
- `tb_pikosol_vram_80x30.sv`: two address-boundary reads and invalid-address check.

For an independent simulation with Icarus Verilog:

```powershell
iverilog -g2012 -s tb_pikosol_vram_80x30 -o vram_test.vvp .\pikosol_vram_80x30.sv .\tb_pikosol_vram_80x30.sv
vvp .\vram_test.vvp
```

Expected *only if run and passing*: `SIM PASS: 80x30 VRAM boundary and synchronous reads`.

## Console01 integration requirements

1. Obtain the **actual** local `pikosol_console_core.sv` and the complete project/build script. This candidate is not a substitute for them.
2. Merge clear, backspace and character write operations into **one** write request per clock; preserve the original priority and behavior.
3. Ensure the controller clears all 2400 cells during startup before accepting input, or preserve a separately proven initialization mechanism.
4. Keep the video read synchronous; verify latency alignment between text address, glyph ROM, sync and display enable. Avoid assumptions about read/write collisions.
5. Run Gowin synthesis, confirm actual BSRAM usage and DFF utilization, then place/route and timing. Only after full BUILD PASS program volatile SRAM and check real DVI + USB HID. No Flash programming.
6. Do not merge into `main`, publish a release, or claim BOARD PASS until the operator has demonstrated the full console on the board.

Hardware predecessor references:
- `PR25-07-PiKoSoL-TERM-DVI`: prior text terminal, BUILD PASS documented but no BOARD PASS.
- `PR25-TETRIS-HID-06-FIX2`: demonstrated USB HID + DVI on Primer 25K; distinct program, not proof of Console01 integration.

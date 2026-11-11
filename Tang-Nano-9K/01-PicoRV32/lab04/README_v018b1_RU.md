# PiKoSoL LAB-04.3.1 / v0.1.8b1 - Gowin LUT-fit remediation (experimental)

## Reported problem
GowinSynthesis failed with RP0006: 11858 logic units required vs 8640 available on GW1NR-9C.
The new v0.1.8b terminal was not implemented on FPGA. v0.1.8a is the last confirmed HW PASS.

## Corrections
- The huge 96-bit combinational glyph ROM and dynamic bit mux are removed.
- 8x12 font is a 2048x8 synchronous inferred BSRAM ROM (`syn_romstyle=block_rom`), with byte-identical glyph rows from original v0.1.8b.
- 304-byte terminal RAM has one explicit synchronous write port and a synchronous read port (`syn_ramstyle=block_ram`), avoiding flip-flop/LUT RAM inference.
- Video overlay has two elastic pipeline stages, preserving pixels and SOF under backpressure.
- Text row counter grows to 6 bits to count all 40 rows of 12 pixels, avoiding unintended menu duplication after row 31.
- Build stages the ROM initialization file under work cwd and rtl source path. Icarus runs console simulation from its rtl directory to load ROM.
- Original CPU firmware/ROM 771 words, graphics and tty CDC and physical pins are unchanged.

## Validation boundaries
Package authoring checks confirm 95 glyphs preserved and ROM 2048 bytes. GowinSynthesis / PnR / STA and hardware MUST be run on Windows.
If Gowin reports memory inference errors, inspect gowin_cli.log instead of changing resource limits or programming FPGA.
Do not use v0.1.7 Full28 auditor on v0.1.8b1. Run check_sta_v018b.py after a clean CPU build.

## Quick commands
```
cd C:\GitHub\Sipeed-FPGA
& .\01-PicoRV32\lab04\tools\test_lab04.ps1
& .\01-PicoRV32\lab04\tools\build_lab04.ps1 -Mode CPU
```
Do not program SRAM until PnR and v018b STA have passed.

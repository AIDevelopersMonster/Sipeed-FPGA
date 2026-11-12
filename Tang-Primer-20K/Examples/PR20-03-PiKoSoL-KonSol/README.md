# PR20-03 — PiKoSoL / KonSol on Tang Primer 20K

**Status: PLAN / NOT TESTED.**

Development target: a practical small computer, not a game console. Reuse architectural work on terminal/GFX, UART management and the Windows ↔ FPGA file manager; later integrate screen output, program loading, filesystem and BASIC/Forth workflows where appropriate.

Prerequisites: PR20-00 board bring-up, a working CPU+UART SoC and verified display/memory interfaces. Existing software behavior on another board is a porting baseline, **not** proof that it already works on Primer 20K.

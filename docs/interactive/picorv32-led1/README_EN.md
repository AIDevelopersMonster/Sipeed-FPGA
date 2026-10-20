# PicoRV32 / Tang Nano 9K — Interactive LED Demonstration (English)

**Release:** v1.0 · 20 October 2026  
**Author:** A. A. Malachevsky, Independent Researcher  
**ORCID:** https://orcid.org/0009-0008-6009-3196  
**Repository:** https://github.com/AIDevelopersMonster/Sipeed-FPGA

## Included files

- `PicoRV32_LED1_Interactive_Demo_EN.html` — an interactive offline model (one self-contained file).
- `PicoRV32_LED_HTML_Guide_v1.0_EN.pdf` — the illustrated 26-page English guide, including a full page for each of 19 model steps.
- `SHA256SUMS.txt` — SHA-256 checksums for the published HTML files. The illustrated PDF and thumbnail are uploaded separately.

## How to use

Double-click the `.html` file in a modern desktop browser. No server, network access, RTL simulator or FPGA board is required. Select `L1`, click `Reset`, and then press `Step` to follow four RV32I instructions:

```
0x00000000  0x200002B7   lui  t0, 0x20000
0x00000004  0x00100313   addi t1, zero, 1
0x00000008  0x0062A023   sw   t1, 0(t0)
0x0000000C  0x0000006F   jal  zero, stop
```

- Steps 1–4: LUI places the peripheral address 0x20000000 into x5.
- Steps 5–8: ADDI places the value 1 into x6.
- Steps 9–15: SW writes x6 to the MMIO LED register; L1 on FPGA pin 10 lights on step 14, once the SoC register is updated and mem_ready is asserted.
- Steps 16–19: JAL loops forever, while the LED register retains its state.

`Jump to ON` displays step 14 immediately. `Back` and `Auto` support reverse and timed playback. LEDs L1–L6 can be selected; their bit masks and machine code are updated automatically.

## Verification and limitations

The HTML model was tested in a Chromium browser for all 19 steps and all 6 LED targets, and its numeric bus states were compared with the original Russian-language model. The PDF was rasterized and inspected, and all 26 pages were confirmed.

**The HTML is a conceptual instructional model, not a cycle-accurate or gate-level simulator.** It does not execute the actual PicoRV32 Verilog. The four-instruction LED-only example is not independently tested on the physical board. The separate 33-instruction boot project did pass an FPGA test on 19 October 2026 (UART `PICO`, LEDs). No claim of hardware validation for the four-instruction variant is made.

## Author and upstream attribution

The educational demonstration and this guide are credited to **A. A. Malachevsky** (ORCID above). The original processor PicoRV32 was created by **Claire Xenia Wolf** and is available under the **ISC license** at https://github.com/YosysHQ/picorv32. These materials demonstrate the Sipeed-FPGA integration, not an official YosysHQ simulator.
# PicoRV32: from RV32I machine code to FPGA LED L1

**Interactive HTML educational demonstration (RU/EN), v1.0 · 20 October 2026**

**Author:** A. A. Malachevsky / Малачевский А. А. · Independent Researcher  
**ORCID:** https://orcid.org/0009-0008-6009-3196

Open the autonomous HTML file in a local browser (download it with **Raw → Save as**). No network or FPGA board is required after download.

| Language | Interactive HTML | Documentation |
| --- | --- | --- |
| Русский | [PicoRV32_LED1_Interactive_Demo_RU.html](PicoRV32_LED1_Interactive_Demo_RU.html) | [README_RU.md](README_RU.md) |
| English | [PicoRV32_LED1_Interactive_Demo_EN.html](PicoRV32_LED1_Interactive_Demo_EN.html) | [README_EN.md](README_EN.md) |

The example explains four instructions, displayed as **19 educational steps**:

```asm
lui  t0, 0x20000
addi t1, zero, 1
sw   t1, 0(t0)
stop: jal zero, stop
```

The model traces ROM → PicoRV32 decoder → GPR x5/x6 → native memory bus → MMIO LED register → active-low FPGA output for L1, with selectable L1–L6. It is **not** a cycle-accurate RTL simulation. This separate 4-instruction program was **not physically validated**; the main repository's 33-instruction SoC was verified on Tang Nano 9K on 19 October 2026 (SRAM programming, UART PICO, LED animation).

**Binary teaching assets:** illustrated 26-page PDF guides (RU and EN) and a 16:9 video cover are released separately from this first GitHub text commit; verify their presence before citing direct PDF/image links. Their intended directory is this folder and `assets/`.

**Upstream PicoRV32:** Claire Xenia Wolf, ISC-licensed core: https://github.com/YosysHQ/picorv32. This educational visualization is not an official simulator from YosysHQ.

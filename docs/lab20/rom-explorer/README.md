# PiKoSoL LAB-20.4 — Tang Nano 20K / LiteX ROM Explorer v3.2

**Hardware:** Sipeed Tang Nano 20K · factory LiteX SoC · VexRiscv_Min @ 48 MHz.
**Status:** original factory BIOS and CPU-visible ROM captured on physical hardware; HTML is an RV32I educational simulator, not cycle-accurate VexRiscv RTL.

## Open the interactive reference

Open [PiKoSoL ROM Explorer v3.2](PiKoSoL_ROM_Explorer_v3_2.html) after downloading the HTML file, or open [index.html](index.html) from a local checkout. It works offline and embeds the verified 32 KiB ROM.

The interactive tool contains RV32I instruction explanations, machine-word fields, program flow, register and SRAM changes, a call catalog, and an address-alias laboratory.

## Captured ROM and evidence

| Property | Value |
|---|---|
| CPU-visible ROM window | 128 KiB (0x00000000–0x0001FFFF) |
| Unique repeated period | 32 KiB (0x8000 bytes) |
| Canonical binary | PiKoSoL_LAB20_ROM_32KiB.bin |
| Canonical SHA-256 | 3347be74e9716744949e572229345c3ea9e74f1740001408b934c0d85c79c5bc |
| Original acquisition SHA-256 | fac8e6e6f39a22e2995de54c271646687d86ad9802e884b848bcf5b6ec4edb65 |
| BIOS CRC-32 | F2B1F4F6 |
| BIOS image incl. CRC | 26,184 bytes |
| Factory BIOS build | 2023-03-13 |

The first 32 KiB are repeated identically four times in the captured 128 KiB memory window. Reads via the physical BIOS shell at 0x000000B0, 0x000080B0, 0x000100B0 and 0x000180B0 yielded the same 16 bytes, independent of the PowerShell capture script.

This is consistent with LiteX automatically shrinking its ROM memory depth to the compiled BIOS while the declared bus address window remains 128 KiB. **The exact post-synthesis BSRAM topology is not independently verified.** Do not infer the existence of three unused physical banks.

The original 128 KiB capture remains immutable **primary acquisition evidence**. This repository publishes its 32 KiB unique period and the hash of the original, not a replacement for the archival dump.

## Files

- PiKoSoL_ROM_Explorer_v3_2.html / index.html — standalone offline HTML simulator and reference.
- PiKoSoL_LAB20_ROM_32KiB.bin — unique verified BIOS ROM image.
- PiKoSoL_ROM_32KiB_manifest.json — sizes, hashes and archive provenance.
- PiKoSoL_LAB20_reduce_rom_32KiB.ps1 — read-only Windows verification and extraction script.
- test_v32.js — Node.js self-test of the HTML and reference ROM.
- ROM_ALIAS_AUDIT.md — engineering investigation with evidence boundaries.

## Reproduce extraction on Windows

In PowerShell 7, from your local Sipeed-FPGA/docs/lab20/rom-explorer folder:

    pwsh -NoProfile -ExecutionPolicy Bypass -File .\PiKoSoL_LAB20_reduce_rom_32KiB.ps1

Input defaults to captures/PiKoSoL_LAB20_ROM_128KiB.bin and output to captures/PiKoSoL_LAB20_ROM_32KiB.bin. The script verifies the complete original SHA-256 and byte-comparison of all four 32 KiB windows before writing. You can override InputFile and OutputFile.

Test viewer (Node.js 18+):

    node test_v32.js

## What is proven vs. modeled

Proven by read-only physical experiment: LiteX BIOS, address aliases in ROM, 48 MHz CPU, UART/SDRAM startup, original capture hashes and CRC.

Modeled: RV32I instructions, register/PC effects, SRAM initialization, custom interrupt-mask CSR, and execution up to an unknown MMIO read at address 0xF0003010 after 2,194 steps.

Not yet proven: cycle-accurate VexRiscv pipeline, exact MMIO peripheral mapping for this factory build, physical BSRAM instantiation, or actual Wishbone transaction waveforms.

**No FPGA reprogramming is performed by the supplied tools. Preserve factory Flash and recovery options.**

## Sources and publications

- [Main LAB-20 record](../README.md)
- [LiteX BIOS paper (RU/EN)](https://doi.org/10.5281/zenodo.23990004)
- [VexRiscv / VexRiscv_Min paper (RU/EN)](https://doi.org/10.5281/zenodo.23991097)
- [Wishbone 32-bit paper (RU/EN)](https://doi.org/10.5281/zenodo.23991663)
- [LiteX at factory reported revision](https://github.com/enjoy-digital/litex/tree/b05c3069)
- [Tang Nano 20K original board target of March 2023](https://github.com/litex-hub/litex-boards/blob/6b8a5d35c03e408f738a9667c0497f31e25bf0b7/litex_boards/targets/sipeed_tang_nano_20k.py)

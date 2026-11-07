# PiKoSoL LAB-20.4: Factory ROM Address Alias Investigation

Date: 2026-11-07. Device: Tang Nano 20K, factory LiteX BIOS, CPU reported as `VexRiscv_Min @ 48 MHz`.

## Executive finding

The 128 KiB ROM address region reported by the firmware is **not evidence of 128 KiB of independently addressable physical ROM**. The captured image repeats every `0x8000` (32 KiB). A read-only BIOS check at four addresses confirmed equality independently from the PowerShell dumper. The original March 2023 LiteX design contains a ROM auto-resize path that is consistent with this behavior. No independent three-bank selector or non-CPU ROM bus master is defined in the public board target.

**Status**: 32 KiB behavioral period confirmed; exact post-synthesis physical BSRAM depth and A15/A16 gating are still unverified without a factory netlist or Gowin reports.

## Evidence register

| Finding | Status | Evidence |
|---|---|---|
| CPU reports ROM window 0x00000000..0x0001FFFF (128 KiB) | Measured | `mem_list`, BIOS UART |
| `mem_read` at 0xB0, 0x80B0, 0x100B0, 0x180B0 returns same 16 bytes | Measured | Direct user's terminal transcript; independent of script |
| Four 32 KiB quarters have identical bytes | Measured | Full 131,072-byte dump |
| Overall dump SHA256 `fac8e6e6f39a22e2995de54c271646687d86ad9802e884b848bcf5b6ec4edb65` | Measured | File hash |
| Stored CRC32 at `0x6644` equals `0xF2B1F4F6` | Measured | ROM little-endian bytes `F6 F4 B1 F2` |
| CRC32 of byte interval `[0, 0x6644)` equals `0xF2B1F4F6` | Calculated | `zlib.crc32` |
| BIOS image ends at `0x6647` inclusive (26,184 bytes including CRC) | Strong inference | BIOS helper code treats `_edata_rom` as CRC location; no later nonzero byte in a mirror |
| 6546 words require 13 bits to select a word | Arithmetic | `ceil(log2(6546))=13` |
| Effective 32KiB address period: CPU A16:A15 do not distinguish observed ROM contents | Measured / inferred | ROM equality, direct BIOS test |
| One automatically downsized ROM, rather than four independent memory banks | Strong hypothesis | Historic LiteX design and board target |
| Exact number of physical BSRAM macros and actual post-PNR wiring | Unknown | No factory PNR database/netlist available |

## Matched historical software / gateware design

1. [Sipeed official LiteX firmware example](https://github.com/sipeed/TangNano-20K-example/tree/main/litex) includes an `.fs` image; the bitstream first entered Sipeed's repository on March 16, 2023. Its source compilation guide builds the target below.
2. [Tang Nano 20K target as of March 13, 2023](https://github.com/litex-hub/litex-boards/blob/6b8a5d35c03e408f738a9667c0497f31e25bf0b7/litex_boards/targets/sipeed_tang_nano_20k.py) defines a 48 MHz SoC, 8 MiB 32-bit SDRAM, LEDs/buttons and standard LiteX ROM. It does **not** add a four-bank ROM-select controller.
3. [LiteX SoCCore at BIOS git SHA b05c3069](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/integration/soc_core.py) exposes `--integrated-rom-size` default `0x20000` and describes automatic BIOS-size shrinkage.
4. [LiteX builder at BIOS git SHA b05c3069](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/integration/builder.py) loads compiled `bios.bin`, then initializes the integrated ROM.
5. [LiteX `soc.py` at BIOS git SHA](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/integration/soc.py) implements `init_rom` using `getattr(self,name).mem.depth = len(contents)` when `auto_size=True`.
6. [LiteX Wishbone SRAM at BIOS git SHA](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/interconnect/wishbone.py) maps the Wishbone word address to the physical memory address port.
7. [VexRiscv integration at BIOS git SHA](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/cores/cpu/vexriscv/core.py) specifies `periph_buses=[ibus,dbus]`: separate instruction and data masters, both using the same SoC slave address map.
8. [BIOS helper at BIOS git SHA](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/software/bios/helpers.c) computes CRC over bytes from `_ftext` to `_edata_rom` and treats the word at `_edata_rom` as the expected CRC value.
9. [Migen memory construction](https://github.com/m-labs/migen/blob/master/migen/fhdl/specials.py) creates an address signal from memory depth. Note that creation and resize order can differ; **the exact signal widths after synthesis must not be asserted solely from these Python sources**.

## Address interpretation

For the observed image, an effective model is:

```text
CPU byte address A = [A16 A15 | A14 ........ A2 | A1 A0]
ROM observed offset  = A & 0x7FFF
ROM observed word    = (A >> 2) & 0x1FFF
```

Example:

```text
0x000000B0 -> 0x00B0
0x000080B0 -> 0x00B0
0x000100B0 -> 0x00B0
0x000180B0 -> 0x00B0
```

This is a verified **behavioral mapping** for the captured factory image, NOT a statement that a particular 13-bit RTL wire was observed. The public Python HDL allocates a 128 KiB region first and later resizes the backing memory: after-PNR netlist inspection is needed to establish how the unused high bits disappear in gates.

## Independent resource sanity check

The board's documented BSRAM is 828 Kbits (46 primitives), approximately 103.5 KiB. An independently implemented 128 KiB ROM alone would require 1,024 Kbits of storage before the 8 KiB SRAM. This supports automatic ROM downsizing as an economical design. It does not forbid use of distributed LUT ROM or other storage, hence it is corroborating context rather than proof.

[Official board specifications](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)

## Conclusion and claim discipline

The user's alternative hypothesis -- a real 128 KiB ROM with three banks reached by another master -- has not been observed and is not supported by the contemporary published target sources. LiteX's 128 KiB reported ROM is a configured CPU address region; the actual BIOS payload is only 26,184 bytes. The most economical explanation is one ROM resource whose effective address period is 32 KiB within a larger region. The exact physical BRAM layout remains a separate synthesis/netlist question.

No firmware write, FPGA reconfiguration or destructive test is necessary to establish the observed addressing behavior. A definitive physical claim would require the original gateware build directory, netlist, post-PNR implementation or equivalent Gowin memory-primitive report.

## Reproduction

Run this read-only, offline check on a copied binary:

```powershell
python .\verify_rom_alias.py .\PiKoSoL_LAB20_ROM_128KiB.bin
```

Open `PiKoSoL_ROM_Explorer_v3_1.html` and switch to the ROM map section. Change CPU address across four 32 KiB windows; the model shows effective alias offset and captured bytes. The HTML self-test is implemented in `test_v31.js` and can run with Node.js. The model does not pretend to be a transistor/RTL or cycle-accurate representation.

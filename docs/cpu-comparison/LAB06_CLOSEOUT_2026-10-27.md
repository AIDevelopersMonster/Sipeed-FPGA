# LAB-06 — Final closeout / Завершение программы

**Date: 2026-10-27. Status: COMPARATIVE EXPERIMENT COMPLETE, NO FURTHER REQUIRED TESTS.**

This is the agreed bounded PicoRV32-vs-NEORV32 comparison on Sipeed Tang Nano 9K, not an assertion of formal full-ISA or production-level FPGA certification.

## Completed and physically observed

1. **LAB-06.1 NEORV32:** native VHDL core integrated with UART and six LEDs. Real volatile-SRAM programming, UART `NEORV32 READY` and three physical LEDs **BOARD BASIC PASS**; original accepted bitstream SHA256 `3E1DC3EB6DC464E3992C733078A564680D5F279E4D89BAA8A47CB9002246FC5F`.
2. **LAB-06.2 PicoRV32:** native Verilog CPU integrated with ROM/RAM and UART/GPIO. Real volatile-SRAM programming, 16-byte `PICORV32 READY\r\n`, three physical LEDs **BOARD BASIC PASS**; original accepted bitstream SHA256 `31691075B56BB4167758AEB9D99CE8E7F4CE0BE84333D527FD2659606025F4A0`.
3. **W01 hardware benchmark:** independently calculated checksum `B26F8CA7`; exact 62 instruction words matched, both RTL SIM PASS, both independent Gowin FIT/STA pre-board screens PASS, two new SHA-locked SRAM loads, two exact 23-byte UART data frames with **simulation cycles = FPGA cycles**.

| W01 27 MHz | PicoRV32 | NEORV32 |
| --- | ---: | ---: |
| Board `cycle` CSR | **39,609** | **38,162** |
| Simulation `cycle` CSR | 39,609 | 38,162 |
| UART/frame/digest | PASS | PASS |
| Counter-enabled SoC logic | 1,654 (20%) | 3,696 (43%) |
| Counter-enabled SoC registers | 617 (10%) | 2,058 (31%) |
| BSRAM in full SoC | 54% | 20% |

**W01 finding:** NEORV32 used **1,447 fewer cycles (3.65%)**, corresponding to **53.59 µs less** execution time at 27 MHz on this deterministic workload. The SoCs have **different memory/peripheral implementations**. These are NOT isolated CPU-core area/speed numbers.

## Explicitly not certified

- W01's physical **three-LED visual confirmation is still pending** in both automatic receipts; do not rewrite the receipt or turn it into a visual PASS.
- Pico W01 Recovery/Removal has no analyzed paths and so asynchronous reset deassertion is not timing-signed-off. External timing/CDC analysis is incomplete.
- No primitive-level explanation is established for 54% vs 20% BSRAM. No pure CPU-core area measurement, physical Fmax, complete RV32I compliance suite or multi-sample speed statistics.
- W02/W03 and additional comparative tests were cancelled to meet the user's 1-day and 2–3 documented-test stopping policy.

## Publication and retention

- [**Final W01 report, actual bitstream SHA and UART logs reproduced**](w01/RESULTS_W01_2026-10-27.md).
- [W01 source code and CLI scripts](w01/README.md).
- [NEORV32 basic physical acceptance](../../02-NEORV32/acceptance/LAB061_BOARD_2026-10-26.md).
- [PicoRV32 basic physical acceptance](../../01-PicoRV32/lab06/acceptance/LAB062_BOARD_2026-10-27.md).
- Source builds, fit receipts and raw serial data live in the operator's Windows `_build` directories, **not** GitHub. This closeout is based on the operator's supplied logs and does not claim to have independently recovered those private local files.

**Final disposition:** ``LAB06_EXPERIMENT_CLOSED``. Accepted LAB-06.1 and LAB-06.2 bitstreams remain unchanged; no further FPGA work required for this comparison.

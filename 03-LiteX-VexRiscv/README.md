# 03 — LiteX / VexRiscv

**Status: research plan / no synthetic result or board verification yet.**

Target hardware: Tang Primer **25K** (GW5A), own Dock model must be verified. Reference target in LiteX:
[`litex-hub/litex-boards/litex_boards/targets/sipeed_tang_primer_25k.py`](https://github.com/litex-hub/litex-boards/blob/master/litex_boards/targets/sipeed_tang_primer_25k.py).
Upstream CPU: [`SpinalHDL/VexRiscv`](https://github.com/SpinalHDL/VexRiscv).

## LAB-20.6 — RAM-only диагностика на заводской Tang Nano 20K

**[Исходный код RV32I, BIN 740 байт, PowerShell-загрузчик и тесты](lab20-6-ram-diag/README.md).** Это отдельная работа с уже установленным **заводским LiteX / VexRiscv_Min** на Tang Nano 20K, а не с планируемой самостоятельной сборкой для Primer 25K.

Статус: `BUILD_PASS / RV32_SIM_PASS / BOARD_TEST_PENDING`. Программа снимает состояние UART до первого собственного вывода и после вывода, сохраняя результаты в SDRAM. Установка только во временную SDRAM `0x40010000`; заводская Flash не изменяется. `boot 0x40010000` необратимо передаёт управление до аппаратного RESET.

## Planned milestones

1. Pin a known LiteX/VexRiscv/litex-boards toolchain and inspect toolchain compatibility with the Gowin Education version.
2. Build minimal UART LiteX SoC on available logic with on-chip memory (no external SDRAM assumption).
3. Verify firmware boot and serial BIOS by simulation before hardware if an executable simulator is available.
4. Add LiteX CSR peripheral exposing common LED, clock counter, device ID and completion status.
5. Enable optional SDRAM as a distinct configuration and independently test memory stability.
6. Document generated RTL, CPU parameterization, memory map, resource report, build time/host RAM.

LiteX is a **SoC generation and integration framework**, not another standalone CPU comparable one-to-one to PicoRV32. Compare a defined VexRiscv configuration plus bus/memory/peripherals, and optionally compare isolated core footprints separately.

## Feasibility

Official LiteX target includes support for a GW5A PLL, UART via USB ACM, optional SDR SDRAM, SPI Flash and GPIO. Third-party practical example: [`ckshum88/litex-primer25k`](https://github.com/ckshum88/litex-primer25k). Physical memory and Dock type must be confirmed before assuming functionality.

This release includes **no `pip install`, SoC build or programming command**, because supported dependency versions have not yet been fixed/tested. See root `sources.lock.json` for reference snapshots.

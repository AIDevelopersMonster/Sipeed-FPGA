# Дорожная карта: Tang Nano 9K от первого USB до PiKoSoL

[← Старт](README.md) · [Реестр работающих .fs](VERIFIED_BUILDS.md)

| № | Этап | Что повторить | Подтверждение |
| --- | --- | --- | --- |
| 00A | Готовая рабочая FPGA | [WebUSB → PiKoSoL → UART/HDMI](START_HERE_RU.md) | BOARD PASS, v0.2.0 |
| 00B | Свой Verilog, без CPU | [LAB-00: бегущий светодиод](examples/00-led/README.md), 27 МГц | **PREPARED / NOT TESTED** |
| 01 | Приём UART, HTML → FPGA | [LAB-02](docs/lab02/README.md) | BOARD PASS |
| 02 | Процессор RV32I, ROM, MMIO | [PicoRV32](01-PicoRV32/README.md) | BOARD PASS в описанном объёме |
| 03 | Свой терминал, графика и HDMI | [LAB-04 PiKoSoL](docs/lab04/README.md) | BOARD PASS |
| 04 | Цифровые игры без процессора | [PONG](games/pong-rgb/README.md) и [BREAKOUT](games/breakout-rgb/README.md) | BOARD PASS; распространение .fs различается |
| 05 | SPI байтовый обмен | [SPI-01](examples/peripherals/spi/01-mode0-byte/README.md) | Изучить отдельный протокол |
| 06 | microSD, секторы, FAT32 | [SD-01…08](boards/tang-nano-9k/experiments/README.md) | Смешанные; SD-02 чтение BOARD PASS, SD-06 запись ограниченный BOARD PASS |
| 07 | Второй RISC-V | [NEORV32 LAB-06.1](02-NEORV32/README.md) | Basic UART/LED BOARD PASS; сравнительные измерения NOT RUN |
| 08 | Память и расширение системы | [PSRAM LAB-07](boards/tang-nano-9k/experiments/psram07/README.md) | Исследовательский статус |

### Как проходить

**Начинающему:** 00A → 00B → 01 → 03. **Инженеру RTL:** 00B → 01 → 04 → 05. **Разработчику SoC:** 02 → 03 → 06 → 07 → 08.

Для каждого этапа отдельно фиксируйте: точную цель, RTL/тестбенч, ограничения пинов и частоты, PnR/STA, SHA256 `.fs`, факт SRAM Program, наблюдение на физической плате и ограничения результата. Не превращайте успешную компиляцию в BOARD PASS.

Новые учебные кандидаты не публикуются как рабочие релизы до аппаратной приёмки. Архив технических работ сохранён в [полном каталоге](docs/PROJECT_CATALOG.md).

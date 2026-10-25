# Sipeed FPGA — PiKoSoL и проверенные лаборатории

**Tang Nano 9K · RISC-V PicoRV32 · HDMI · UART · SPI / microSD · WebUSB**

Здесь собраны **работающие результаты, исходники и воспроизводимые учебные примеры**. Отметка **BOARD PASS** относится только к конкретному испытанному стенду и версии, а не к любой новой сборке.

## Начните здесь: PiKoSoL v0.2.0

**[1. Прошить FPGA через браузер](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-loader/)** · **[2. Открыть Web Serial](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-control/)** · **[Релиз и прошивка v0.2.0](https://github.com/AIDevelopersMonster/Sipeed-FPGA/releases/tag/pikosol-v0.2.0)**

1. Подключите Tang Nano 9K. В Chrome/Edge откройте загрузчик и выберите **PiKoSoL v0.2.0**.
2. Получите файл с GitHub, выберите **JTAG Debugger (FT2232, канал A)** и загрузите его **в SRAM**. Проверьте HDMI.
3. Откройте Web Serial, подключите **COM-порт (FT2232, канал B, 115200 8N1)** и используйте команды **HELP, INFO, LED, TERM, GFX**.

**BOARD PASS, 23.10.2026:** подтверждены WebUSB, настоящая FPGA, PicoRV32, UART, LED и HDMI. [Возможности PiKoSoL](docs/lab04/README.md) · [Протокол аппаратной приёмки](docs/lab04/LAB044_ACCEPTANCE_2026-10-23_RU.md). Браузерный программатор не записывает конфигурационную Flash.

## Что можно использовать

| Результат | Содержимое | Статус |
| --- | --- | --- |
| **[PiKoSoL v0.2.0](docs/lab04/README.md)** | Готовая прошивка, PicoRV32, HDMI, UART, WebUSB и Web Serial | **BOARD PASS**, публичный релиз |
| **[LAB-02: HTML ↔ FPGA ↔ LED](docs/lab02/README.md)** | RU/EN инструкции, исходники, реальное управление LED из HTML | **BOARD PASS** |
| **[LED1 — декодер RISC-V](docs/interactive/picorv32-led1/README.md)** | Автономная HTML-модель, 4 инструкции и 19 шагов | Готовая учебная модель, не цикл-точный RTL |
| **[SD-02 — чтение microSD](boards/tang-nano-9k/experiments/sd-multilba/README.md)** | Четыре LBA, CRC16, UART, исходники и тесты | **BOARD PASS**, только чтение |
| **[SD-06 — секторная запись](boards/tang-nano-9k/experiments/sd06-cmd24/README.md)** | CMD17/CMD24, проверка записи и восстановление сектора | **Ограниченный BOARD PASS**: одна тестовая SD и один разрешённый LBA |
| **[SPI и microSD — учебные материалы](docs/education/README.md)** | PDF, Markdown, RTL и методика проверки | Опубликованные учебные материалы |

## Что не готово как продукт

- **SD-08 (FAT32 read-only):** на плате получены FS, DIR и TYPE PIKO.TXT, но проверенный бинарный файл **не опубликован для автоматической загрузки**. [Статус SD-08](docs/lab04/web-loader/README_SD08_WEB_LAB.md).
- **PicoTiny / заводская PicoSoc:** пример PicoTiny не является подтверждённой копией заводской прошивки; восстановление Flash не проверено.
- **Остальные RTL-эксперименты:** [каталог Tang Nano 9K](boards/tang-nano-9k/experiments/README.md) и [LAB-03](docs/lab03/README.md). Наличие исходников само по себе не означает BOARD PASS.
- **Другие CPU:** [NEORV32](02-NEORV32/README.md), [LiteX/VexRiscv](03-LiteX-VexRiscv/README.md), [Rocket](04-Rocket/README.md) — исследовательские направления, не аппаратные релизы.

## Документация и разработка

[Статья PiKoSoL RU/EN — DOI](https://doi.org/10.5281/zenodo.23593101) · [SPI — DOI](https://doi.org/10.5281/zenodo.23608792) · [SD — DOI](https://doi.org/10.5281/zenodo.23608853)

Сборка, STA, тесты и аппаратные протоколы описаны в каждой лаборатории. Не переносите результаты испытания одного bitstream на другой. Не записывайте Flash без проверенного пути восстановления.

**Правило Git:** main — понятная посетителю проверенная основа. Изолированные ветки допустимы, когда у них есть конкретная задача, критерий завершения и план закрытия. [История консолидации](docs/BRANCH_CONSOLIDATION_2026-10-25.md).

---

**English quick start.** [Program Tang Nano 9K via WebUSB](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-loader/) with the verified PiKoSoL v0.2.0 image (**volatile SRAM only**), then [open Web Serial](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-control/). [Download v0.2.0](https://github.com/AIDevelopersMonster/Sipeed-FPGA/releases/tag/pikosol-v0.2.0). The table distinguishes board-tested projects, educational demos and unfinished work. **SD-08 auto-download and factory recovery are not released.**

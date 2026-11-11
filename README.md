# Sipeed FPGA — PiKoSoL и проверенные лаборатории

**Tang Nano 9K · RISC-V PicoRV32 · HDMI · UART · SPI / microSD · WebUSB**

Здесь собраны **работающие результаты, исходники и воспроизводимые учебные примеры**. Отметка **BOARD PASS** относится только к конкретному испытанному стенду и версии, а не к любой новой сборке.

## Tang Nano 9K — наши проекты в одном каталоге

**[ОТКРЫТЬ TANG NANO 9K — PiKoSoL, PicoRV32, NEORV32, SD, LAB-02–07, Pong, Breakout](Tang-Nano-9K/README.md)**

Рабочие исходники и аппаратные эксперименты сгруппированы в `Tang-Nano-9K/`. Сайт прошивки **[WebUSB Loader](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-loader/)** и **[Web Serial](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-control/)** продолжает использовать прежнюю защищённую директорию `docs/`. Она **не перемещалась и не менялась**.

## Tang Primer 25K — процессорная лаборатория

**[ОТКРЫТЬ TANG PRIMER 25K →](Tang-Primer-25K/README.md)** · **[Начало работы](Tang-Primer-25K/START_HERE_RU.md)** · **[PR25-00: аппаратная аттестация](Tang-Primer-25K/Examples/PR25-00-Board-Bringup/README.md)**

**Комплектация:** Tang Primer 25K + Dock. Новый исследовательский стенд для PicoRV32, VexRiscv, собственного RV32I, системной памяти и процессорных измерений. **Статус: структура создана, аппаратные испытания не проводились.**

## Tang Nano 20K — начните здесь

**[ОТКРЫТЬ ПРОЕКТ TANG NANO 20K →](Tang-Nano-20K/README.md)**

**[Сторонние SoC / ThirdParty](Tang-Nano-20K/ThirdParty/README.md)** · **[Z80 + CP/Mish на реальной плате: BOARD PASS](Tang-Nano-20K/ThirdParty/Z80/README.md)** · [Видео запуска CP/Mish (Shorts)](https://www.youtube.com/shorts/QhGcYvSqoDw)

**Что это:** заводской LiteX с процессором **VexRiscv_Min (RISC-V)**. Изучаем BIOS, ROM и UART, а затем запускаем **свои программы из SDRAM** — без изменения заводской FPGA-прошивки.

**Реальный результат 08.11.2026:** загрузили собственную программу **740 байт**, подтвердили обратное чтение **740/740**, запустили VexRiscv_Min командой `boot 0x40010000` и получили собственный UART-отчёт. Аппаратный эксперимент подтвердил изменение `TXEMPTY=1 → 0` после начала диагностической печати.

**[BIOS/LiteX: устройство, команды, ROM и HTML-эмулятор](Tang-Nano-20K/BIOS/LiteX/README.md)** · **[Понятно: что и зачем делаем](Tang-Nano-20K/START_HERE_RU.md)** · **[Повторить на Windows, пошаговая инструкция](Tang-Nano-20K/REPRODUCE_LAB20_6_RU.md)** · **[ROM Explorer](Tang-Nano-20K/04-ROM-Explorer/README.md)** · **[Исходник, BIN и доказательства LAB-20.6](Tang-Nano-20K/06-RV32-RAM-Diagnostics/README.md)**

---

## Начните здесь: PiKoSoL v0.2.0

**[1. Прошить FPGA через браузер](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-loader/)** · **[2. Открыть Web Serial](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-control/)** · **[Релиз и прошивка v0.2.0](https://github.com/AIDevelopersMonster/Sipeed-FPGA/releases/tag/pikosol-v0.2.0)**

1. Подключите Tang Nano 9K. В Chrome/Edge откройте загрузчик и выберите **PiKoSoL v0.2.0**.
2. Получите файл с GitHub, выберите **JTAG Debugger (FT2232, канал A)** и загрузите его **в SRAM**. Проверьте HDMI.
3. Откройте Web Serial, подключите **COM-порт (FT2232, канал B, 115200 8N1)** и используйте команды **HELP, INFO, LED, TERM, GFX**.

**BOARD PASS, 23.10.2026:** подтверждены WebUSB, настоящая FPGA, PicoRV32, UART, LED и HDMI. [Возможности PiKoSoL](docs/lab04/README.md) · [Протокол аппаратной приёмки](docs/lab04/LAB044_ACCEPTANCE_2026-10-23_RU.md). Браузерный программатор не записывает конфигурационную Flash.

## PONG RGB v1.2 — аппаратная игра на Tang Nano 9K

**Оператор подтвердил работу на плате 26.10.2026.** Pong реализован в Verilog без CPU PicoRV32, выводит игру по HDMI, управляется клавиатурой через Web Serial (UART, 115200 8N1). Исходники и страница управления опубликованы; бинарный `.fs` пока доступен только локально и **не размещён для автоматической загрузки**. Программирование — **только SRAM**.

**[Открыть управление Pong](https://aidevelopersmonster.github.io/Sipeed-FPGA/pong-rgb/)** · **[Исходники, сборка, лицензии](Tang-Nano-9K/games/pong-rgb/README.md)** · [WebUSB загрузчик](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-loader/)

## Что можно использовать

| Результат | Содержимое | Статус |
| --- | --- | --- |
| **[PONG RGB v1.2](Tang-Nano-9K/games/pong-rgb/README.md)** | HDMI Pong, Web Serial, Verilog без CPU | **Оператор: BOARD PASS**; исходники опубликованы, `.fs` локально |
| **[PiKoSoL v0.2.0](docs/lab04/README.md)** | Готовая прошивка, PicoRV32, HDMI, UART, WebUSB и Web Serial | **BOARD PASS**, публичный релиз |
| **[LAB-02: HTML ↔ FPGA ↔ LED](docs/lab02/README.md)** | RU/EN инструкции, исходники, реальное управление LED из HTML | **BOARD PASS** |
| **[LED1 — декодер RISC-V](docs/interactive/picorv32-led1/README.md)** | Автономная HTML-модель, 4 инструкции и 19 шагов | Готовая учебная модель, не цикл-точный RTL |
| **[SD-02 — чтение microSD](Tang-Nano-9K/boards/tang-nano-9k/experiments/sd-multilba/README.md)** | Четыре LBA, CRC16, UART, исходники и тесты | **BOARD PASS**, только чтение |
| **[SD-06 — секторная запись](Tang-Nano-9K/boards/tang-nano-9k/experiments/sd06-cmd24/README.md)** | CMD17/CMD24, проверка записи и восстановление сектора | **Ограниченный BOARD PASS**: одна тестовая SD и один разрешённый LBA |
| **[SPI и microSD — учебные материалы](docs/education/README.md)** | PDF, Markdown, RTL и методика проверки | Опубликованные учебные материалы |
| **[Tang Nano 20K — LAB-20.6](Tang-Nano-20K/README.md)** | Заводской LiteX/VexRiscv, ROM, UART CSR, собственная RAM-only программа, полная инструкция повторения | **BOARD PASS**, RISC-V программа реально выполнена |

## Полезные ссылки — Tang Nano 9K

- **[hi631/tang-nano-9K](https://github.com/hi631/tang-nano-9K)** — сторонняя коллекция проектов для Tang Nano 9K с инструкциями автора (Qiita, японский язык): запуск **BASIC, CP/M-80, CP/M-68K, DOS, NES**; расширения NES с **USB-геймпадом, DRAM для CHR.ROM, звуком по HDMI и загрузкой с SD-карты**. Полезна как источник готовых архитектур и демонстраций. Эти проекты не являются нашими разработками и не имеют статуса BOARD PASS в нашей лаборатории.

## Что не готово как продукт

- **SD-08 (FAT32 read-only):** на плате получены FS, DIR и TYPE PIKO.TXT, но проверенный бинарный файл **не опубликован для автоматической загрузки**. [Статус SD-08](docs/lab04/web-loader/README_SD08_WEB_LAB.md).
- **PicoTiny / заводская PicoSoc:** пример PicoTiny не является подтверждённой копией заводской прошивки; восстановление Flash не проверено.
- **Остальные RTL-эксперименты:** [каталог Tang Nano 9K](Tang-Nano-9K/boards/tang-nano-9k/experiments/README.md) и [LAB-03](docs/lab03/README.md). Наличие исходников само по себе не означает BOARD PASS.
- **Другие CPU:** [NEORV32](Tang-Nano-9K/02-NEORV32/README.md), [Rocket](04-Rocket/README.md) — исследовательские направления. **[LiteX/VexRiscv на Tang Nano 20K](Tang-Nano-20K/README.md) — уже имеет аппаратно подтверждённое исполнение собственной RISC-V программы из SDRAM**, но это не собственный FPGA bitstream.

## LAB-06 — сравнение процессоров и типовых блоков

**Следующий эксперимент: NEORV32 на Tang Nano 9K**, затем измеримое сравнение с PicoRV32 при одинаковых исходных условиях (RV32I, 27 МГц, сопоставимые ROM/RAM, UART и GPIO). Отдельно исследуются **ALU, регистровый файл, декодер инструкций, шинные адаптеры**, а также типовые **UART, GPIO, таймер, SPI и SD CMD17 (только чтение)**. Разделяем результаты **CPU core**, **native SoC** и **одинаковые внешние периферийные RTL-блоки**. Пока статус **PLAN / NOT MEASURED**, а не новый аппаратный релиз.

[LAB-06: архитектура и программа сравнения](docs/cpu-comparison/README.md) · [Сравнение типовых блоков](docs/cpu-comparison/TYPICAL_BLOCKS.md) · [Протокол измерений](docs/cpu-comparison/BENCHMARK_PROTOCOL.md) · [Пустые таблицы результатов](docs/cpu-comparison/RESULTS_TEMPLATE.md)

## LAB-20 — Tang Nano 20K / LiteX BIOS

**Factory BOARD PASS:** Tang Nano 20K with LiteX BIOS and VexRiscv_Min @ 48 MHz; COM25 UART console; 8 MiB SDRAM initialized and 2 MiB memtest passed. BIOS-measured sequential throughput: **12.9 MiB/s write**, **16.1 MiB/s read**. This is a test of the **factory SoC**, not a PiKoSoL-built bitstream.

**[LAB-20 technical README and acceptance record](docs/lab20/README.md)** · **[LiteX BIOS technical article (RU/EN), DOI 10.5281/zenodo.23990004](https://doi.org/10.5281/zenodo.23990004)**

**LAB-20 publications (RU/EN):** [VexRiscv / VexRiscv_Min — DOI 10.5281/zenodo.23991097](https://doi.org/10.5281/zenodo.23991097) · [WISHBONE 32-bit — DOI 10.5281/zenodo.23991663](https://doi.org/10.5281/zenodo.23991663).

**LAB-20.4 ROM Explorer v3.2:** [Интерактивный справочник RV32I и заводского LiteX BIOS](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab20/rom-explorer/) · [32 KiB ROM, SHA-256 и воспроизводимый аудит](docs/lab20/rom-explorer/README.md). Считанное окно 128 КиБ содержит четыре зеркала по 32 КиБ; BSRAM-топология после синтеза ещё не подтверждена.

**LAB-20.5 CSR / UART:** [PiKoSoL ROM Explorer v3.3](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab20/rom-explorer/) — различие процессорных CSR и LiteX MMIO, восстановленный UART EventManager на `0xF0003000`, реальная последовательность BIOS `uart_init()`. [Аудит и источники](docs/lab20/rom-explorer/CSR_UART_LAB20_5.md).

**LAB-20.6 / Tang Nano 20K:** [RAM-only программа для VexRiscv_Min, исходники и загрузчик](03-LiteX-VexRiscv/lab20-6-ram-diag/README.md). **Аппаратный запуск PASS 2026-11-08**: 740 байт в SDRAM, полный readback, собственный UART-отчёт и TXEMPTY 1→0. [Протокол](03-LiteX-VexRiscv/lab20-6-ram-diag/RV32_HARDWARE_EXECUTION_PASS_2026-11-08.md). Заводская FPGA Flash остаётся неизменной.

## Документация и разработка

[Статья PiKoSoL RU/EN — DOI](https://doi.org/10.5281/zenodo.23593101) · [SPI — DOI](https://doi.org/10.5281/zenodo.23608792) · [SD — DOI](https://doi.org/10.5281/zenodo.23608853)

Сборка, STA, тесты и аппаратные протоколы описаны в каждой лаборатории. Не переносите результаты испытания одного bitstream на другой. Не записывайте Flash без проверенного пути восстановления.

**Правило Git:** main — понятная посетителю проверенная основа. Изолированные ветки допустимы, когда у них есть конкретная задача, критерий завершения и план закрытия. [История консолидации](docs/BRANCH_CONSOLIDATION_2026-10-25.md).

---

**English quick start.** [Program Tang Nano 9K via WebUSB](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-loader/) with the verified PiKoSoL v0.2.0 image (**volatile SRAM only**), then [open Web Serial](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-control/). [Download v0.2.0](https://github.com/AIDevelopersMonster/Sipeed-FPGA/releases/tag/pikosol-v0.2.0). The table distinguishes board-tested projects, educational demos and unfinished work. **SD-08 auto-download and factory recovery are not released.**

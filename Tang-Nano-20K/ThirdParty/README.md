# ThirdParty — сторонние процессорные системы для Tang Nano 20K

[← Tang Nano 20K](../README.md) · [Примеры платы (отдельный раздел)](../Examples/README.md)

**Здесь сохранён общий каталог всех ранее рассмотренных сторонних SoC.** В отличие от `Examples/`, каждый новый проект процессора получит собственную папку `ThirdParty/<CPU>/`, когда начнутся практические работы. Не удалять кандидатов из реестра при переносе файлов реализованного проекта.

## Каталог сторонних проектов

Текущий перечень — **реестр внешних источников, не рейтинг качества**. Наличие модуля в исходниках не равно демонстрации его работы на нашей плате. Задача исследования: **сначала штатный запуск автора → протокол фактических наблюдений → независимые обзоры исходников нескольких ИИ → лишь затем сравнение с PiKoSoL 20K**. До воспроизведения upstream не меняем его архитектуру.

| № | Внешний проект / первоисточник | Что заявлено или доступно в исходниках | Наш статус |
|---|---|---|---|
| 1 | **[nano-Z80](Z80/README.md)** — [venomix666/nano-z80](https://github.com/venomix666/nano-z80) | Z80, HDMI-терминал, UART, SD, CP/Mish; см. отдельный рабочий раздел | **BOARD PASS** по существующему протоколу 11.11.2026: CP/Mish, COM25, `A>DIR` |
| 2 | [nano6502 — venomix666](https://github.com/venomix666/nano6502) | 65C02, блоковая RAM/ROM, HDMI 640×480 80 колонок, SD, LED/WS2812, UART, звук, CP/M-65 | Источник доступен; **BOARD NOT TESTED** в рамках нашего стенда |
| **3 — P01** | **[tangyRiscVSOC — qubeck78](PicoRV32/tangyRiscVSOC/README.md)** · [upstream](https://github.com/qubeck78/tangyRiscVSOC) | PicoRV32, HDMI DVI, SDRAM/DMA, графика 2D и 3D, SPI/SD, I2S, USB HID; приоритет изучения полной интеграции | **Первый кандидат для наблюдения; BOARD NOT TESTED** |
| 4 | [calint/tang-nano-20k--riscv--cache-sdram](https://github.com/calint/tang-nano-20k--riscv--cache-sdram) | Собственное ядро RV32I, кэш, SDRAM, Flash, SD SPI, UART; есть программный эмулятор | Источник доступен; **BOARD NOT TESTED** |
| 5 | [PMohan-27/RISCV-SoC](https://github.com/PMohan-27/RISCV-SoC) | RV32I, кэш инструкций, контроллер SDRAM, SPI/SD, GPIO, AXI4-Lite, загрузчик с SD | Источник доступен; **BOARD NOT TESTED** |
| 6 | [LiteX board target: sipeed_tang_nano_20k](https://github.com/litex-hub/litex-boards/blob/master/litex_boards/targets/sipeed_tang_nano_20k.py) · [pins](https://github.com/litex-hub/litex-boards/blob/master/litex_boards/platforms/sipeed_tang_nano_20k.py) | Опорная система LiteX: LED chaser, RGB WS2812, GPIO, UART, SDRAM, HDMI-режимы, SPI SD / SDIO | В нашем проекте **factory LiteX имеет отдельные подтверждения**, но полный upstream-таргет с SD/HDMI **не проходил общий BOARD PASS** |
| 7 | [Sipeed/TangNano-20K-example](https://github.com/sipeed/TangNano-20K-example) | Официальные примеры платы: HDMI PHY, периферия и IP Gowin; поставщик опорных HDL-модулей | **Vendor reference**, отдельные образцы проверялись в Examples; не выдавать это за проверку всех демо |

Статусы `SOURCE AVAILABLE`, `SOURCE REVIEW`, `SIM PASS`, `BUILD/STA PASS` и `BOARD PASS` не взаимозаменяемы. Первый активный кандидат **P01 — tangyRiscVSOC**, потому что одновременно демонстрирует множество узлов 20K и использует PicoRV32. Z80 остаётся уже проверенным проектом, nano6502 — самостоятельным следующим кандидатом без искусственного закрытия.

**[Единый протокол независимого исследования и участия нескольких ИИ](REVIEW_PROTOCOL_RU.md)**. Отчёты других моделей заносим только после их фактического получения, с указанием модели, источников и даты. До того не приписываем им выводы.

## Рабочий проект Z80

- **[Z80 — все действующие файлы](Z80/README.md)** — скрипты запуска, описание системы и Nano Commander
- **[Прямой маршрут CP/Mish](Z80/CPMISH_START_RU.md)** — от заводской LiteX до `A>DIR`
- **[Gowin SRAM-only](Z80/program-nano-z80-gowin.ps1)** · **[временные такты MS5351](Z80/tp20-enable-pll-volatile.ps1)**
- **[Nano Commander](Z80/NanoCommander/README.md)** — отдельная программа, аппаратный запуск пока не подтверждён

Видео реального запуска: [CP/Mish на FPGA — YouTube Shorts](https://www.youtube.com/shorts/QhGcYvSqoDw).

## Архив сравнительного исследования

[Расширенный анализ **nano-Z80 и tangyRiscVSOC** от 10.11.2026](Z80/_archive/2026-11-11/EXTENDED_ANALYSIS_RU.md) — исходники, архитектурные блоки, полезные модули, ограничения, лицензии и сравнительные предложения. Документ сохранён как исторический источник: более поздний аппаратный PASS Z80 не отменяет его прежнюю пометку NOT TESTED на дату составления.

Другие промежуточные исследования Z80 находятся в `Z80/_archive/`. **Для воспроизведения CP/Mish читать архив не нужно** — используйте прямую инструкцию. К исследовательским материалам возвращаемся только по отдельной просьбе.

**Безопасность:** программирование сторонней FPGA-конфигурации выполняется в энергозависимую SRAM; заводскую конфигурационную Flash с LiteX сохраняем.

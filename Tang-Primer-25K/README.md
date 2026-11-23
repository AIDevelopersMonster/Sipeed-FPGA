# Tang Primer 25K — Processor Research Laboratory

> **[Старая пошаговая инструкция PiKoSoL: загрузка FPGA → S0 → monitor.bin → освобождение COM10 → File Manager (оригинал от 21.11.2026)](https://github.com/AIDevelopersMonster/Sipeed-FPGA/blob/3f02c59f1da3f74/Tang-Primer-20K/Examples/PR20-03-PiKoSoL-KonSol/SRAM-Startup/README.md)**. Это инструкция **для Tang Primer 20K (GW2A-18C)**, а не для этой платы **Tang Primer 25K (GW5A-25A)**; прошивки между платами не взаимозаменяемы.

**Board:** Sipeed Tang Primer 25K + Dock  
**Focus:** RISC-V processor architectures, SoC integration, memory, buses, and reproducible FPGA measurements.

> **Обновление 15.11.2026:** работа с DVI возобновлена без SDRAM. Наш статический экран KonSol 80×30 получил VIDEO BOARD PASS на Tang Primer 25K. UART-терминал и файловая система ещё не реализованы; сведения о паузе ниже относятся к предыдущему состоянию проекта.

**[PR25 USB Physical Attach Lite 02 — аппаратно подтверждённое определение USB D+/D− через DVI](Examples/PR25-USB-PHYSICAL-02/README.md)**. BOARD VIDEO + PHYSICAL DETECTION PASS (15.11.2026): фотографии 0/1 → 0/0 и счётчик 0011 → 0012. Это измерение GPIO, **не USB Host**; исходники, PowerShell-сборка и видеообложка сохранены, проверенный `.fs` ожидает загрузки с операторского ПК.

**[PR25 USB HID DVI 05 — клавиатура на FPGA, BOARD PASS](Examples/PR25-USB-HID-05/README.md)**: коды клавиш `1E`, `1F`, `20`, `21` подтверждены на плате; [видео Shorts](https://youtube.com/shorts/AShk8CMhZco). Проект Тетрис-06 пока только локальный кандидат, не BOARD PASS.

## Главный вывод по итогам двух суток

**Проблема не в отсутствии работоспособных примеров.** Отдельные готовые/сторонние примеры на данной платформе запускались и давали наблюдаемый результат. Не получилось **разобрать структуру Primer 25K и выделить из проектов переиспользуемые интерфейсные IP-блоки (HDMI/DVI, аудио, UART)**, после чего встроить их в нужную самостоятельную конфигурацию. Рабочий образец стороннего проекта не равен готовому независимому драйверу/IP. Конкретные причины не доказаны; не следует автоматически винить SDRAM, BL616, reset, pinout или инструментальную цепочку. Это недостаток достигнутого уровня архитектурного анализа и интеграции, а не доказанная неисправность платы.

## Подтверждённый результат и ограничения на момент остановки

| Направление | Статус |
| --- | --- |
| JTAG: плата GW5A-25A обнаружена | **PASS** |
| CLI: загрузка FPGA-конфигурации в volatile SRAM | **PROGRAM PASS** (не означает работу её функций) |
| [PMOD BTN + DT + LED](PMOD/BTN-DT-LED/README.md) | **BOARD PASS** — все три модуля испытаны в общем примере Sipeed |
| [HDMI / DVI](PMOD/DVI/WORKING_PROJECTS_RU.md) | **BOARD VIDEO+AUDIO PASS**: оригинальная A2600Nano v2.5 Golden; PR25-13 отозвана после неуспешного повторного испытания. Отдельно VIDEO PASS: Brus-16 и PR25-08..10. Независимый IP для PiKoSoL не выделен |
| USB Host клавиатура → UART | **NOT TESTED / BOARD PASS отсутствует** |
| UART / UARTTX / терминал | **Независимый интерфейс из рабочих примеров не извлечён; целевой терминал BOARD PASS не получил** |
| Аудио | **BOARD AUDIO PASS подтверждён** на оригинальной Golden A2600Nano v2.5; PR25-13 отозвана из-за невоспроизводимости; самостоятельный звуковой IP для PiKoSoL не интегрирован |
| RISC-V / PiKoSoL 25K | **NOT IMPLEMENTED / BOARD PASS отсутствует** |
| Заводская рабочая конфигурация FPGA | **Восстановление не подтверждено** |
| Внешняя SDRAM | **Модуль отсутствует; ожидание поставки** |

**Правило сохранения:** рабочими считать только конкретные проверенные на плате варианты с доказательствами. PREPARE PASS, BUILD PASS и успешная отправка .fs через CLI не равны BOARD PASS. Непроверенные и нерабочие сборки не представлять как готовые релизы.

**Условие возобновления:** получение модуля SDRAM. После его поступления **возобновить работу над проектом**. Начать с исследования структуры уже работающих образцов и интерфейсных зависимостей (top, pinout, clocks, reset, память, IP), одновременно проверить интеграцию SDRAM. Само наличие SDRAM не доказывает устранения прежних ошибок интеграции HDMI, UART и аудио; причины нужно установить экспериментально.

**Область сохранения:** сохранять подтверждённые рабочие образцы, их точные версии, исходники и краткие доказательства; не смешивать с нерабочими сборками, не заявлять BOARD PASS для целевой интеграции.

**[KonSol 25K — собственная псевдографика](Examples/PR25-KonSol-DVI/README.md)** · **[Как использовать IP Gowin DVI_TX](../ip/hdmi/gowin-dvi-tx/README.md)**.

## Start here

**[Практический порядок: PMOD → DVI → TF → USB → контроллеры → CPU → ОС → игры](QUICK_START_PLAN.md)**


- [Начало работы (RU)](START_HERE_RU.md)
- [Hardware baseline](Hardware/README.md)
- [PMOD: modules and inventory](PMOD/README.md) — [TF / microSD (available)](PMOD/TF/README.md)
- [PR25-00: Board Bring-up](Examples/PR25-00-Board-Bringup/README.md)
- [PR25-01: PicoRV32](Examples/PR25-01-PicoRV32/README.md)
- [PR25-02: VexRiscv](Examples/PR25-02-VexRiscv/README.md)
- [PR25-03: RV32I Core](Examples/PR25-03-RV32I-Core/README.md)
- [RTL](RTL/README.md) · [Tests](Tests/README.md) · [Tools](Tools/README.md) · [Documentation](Documentation/README.md)

## Research rules

1. Keep board-specific sources and constraints within this directory.
2. Use the same workloads and documented conditions when comparing CPU cores.
3. Report SIM PASS, BUILD PASS, STA PASS, and BOARD PASS separately.
4. Default to volatile SRAM programming; do not modify configuration Flash without a documented recovery procedure.
5. Do not assume an external SDRAM module is installed merely because the Dock is present.

**State:** VIDEO BOARD PASS для статического KonSol 25K (15.11.2026), разработки продолжаются без SDRAM. [PMOD BTN+DT+LED](PMOD/BTN-DT-LED/README.md) BOARD PASS; [PMOD HDMI+audio](PMOD/DVI/WORKING_PROJECTS_RU.md) BOARD PASS for original Golden A2600Nano v2.5 only; PR25-13 status withdrawn, additional VIDEO PASS examples recorded. Reusable HDMI/audio/UART integration into PiKoSoL is unfinished; board outputs themselves have working examples.

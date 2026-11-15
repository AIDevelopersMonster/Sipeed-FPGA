# Tang Primer 25K — Processor Research Laboratory

**Board:** Sipeed Tang Primer 25K + Dock  
**Focus:** RISC-V processor architectures, SoC integration, memory, buses, and reproducible FPGA measurements.

> **Статус на 2026-11-15: PAUSED / ДО ПОСТУПЛЕНИЯ SDRAM.** По решению оператора работы над Tang Primer 25K + Dock приостановлены. **Поступление модуля SDRAM означает возобновление проекта.** До этого новые сборки и перенос IP не выполняются.

## Главный вывод по итогам двух суток

**Проблема не в отсутствии работоспособных примеров.** Отдельные готовые/сторонние примеры на данной платформе запускались и давали наблюдаемый результат. Не получилось **разобрать структуру Primer 25K и выделить из проектов переиспользуемые интерфейсные IP-блоки (HDMI/DVI, аудио, UART)**, после чего встроить их в нужную самостоятельную конфигурацию. Рабочий образец стороннего проекта не равен готовому независимому драйверу/IP. Конкретные причины не доказаны; не следует автоматически винить SDRAM, BL616, reset, pinout или инструментальную цепочку. Это недостаток достигнутого уровня архитектурного анализа и интеграции, а не доказанная неисправность платы.

## Подтверждённый результат и ограничения на момент остановки

| Направление | Статус |
| --- | --- |
| JTAG: плата GW5A-25A обнаружена | **PASS** |
| CLI: загрузка FPGA-конфигурации в volatile SRAM | **PROGRAM PASS** (не означает работу её функций) |
| [PMOD BTN + DT + LED](PMOD/BTN-DT-LED/README.md) | **BOARD PASS** — все три модуля испытаны в общем примере Sipeed |
| [HDMI / DVI](PMOD/DVI/WORKING_PROJECTS_RU.md) | **BOARD VIDEO PASS + AUDIO PASS**: оригинальная A2600Nano v2.5 Golden и **наша PR25-13**; отдельно VIDEO PASS: Brus-16 и PR25-08..10. Независимый IP для PiKoSoL не выделен |
| USB Host клавиатура → UART | **NOT TESTED / BOARD PASS отсутствует** |
| UART / UARTTX / терминал | **Независимый интерфейс из рабочих примеров не извлечён; целевой терминал BOARD PASS не получил** |
| Аудио | **BOARD AUDIO PASS подтверждён** на Golden A2600Nano и PR25-13; самостоятельный звуковой IP для PiKoSoL не интегрирован |
| RISC-V / PiKoSoL 25K | **NOT IMPLEMENTED / BOARD PASS отсутствует** |
| Заводская рабочая конфигурация FPGA | **Восстановление не подтверждено** |
| Внешняя SDRAM | **Модуль отсутствует; ожидание поставки** |

**Правило сохранения:** рабочими считать только конкретные проверенные на плате варианты с доказательствами. PREPARE PASS, BUILD PASS и успешная отправка .fs через CLI не равны BOARD PASS. Непроверенные и нерабочие сборки не представлять как готовые релизы.

**Условие возобновления:** получение модуля SDRAM. После его поступления **возобновить работу над проектом**. Начать с исследования структуры уже работающих образцов и интерфейсных зависимостей (top, pinout, clocks, reset, память, IP), одновременно проверить интеграцию SDRAM. Само наличие SDRAM не доказывает устранения прежних ошибок интеграции HDMI, UART и аудио; причины нужно установить экспериментально.

**Область сохранения:** сохранять подтверждённые рабочие образцы, их точные версии, исходники и краткие доказательства; не смешивать с нерабочими сборками, не заявлять BOARD PASS для целевой интеграции.

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

**State:** PAUSED (2026-11-15), **resume upon SDRAM module arrival**. [PMOD BTN+DT+LED](PMOD/BTN-DT-LED/README.md) BOARD PASS; [PMOD HDMI+audio](PMOD/DVI/WORKING_PROJECTS_RU.md) BOARD PASS for Golden A2600Nano v2.5 and rebuilt PR25-13, additional VIDEO PASS examples recorded. Reusable HDMI/audio/UART integration into PiKoSoL is unfinished; board outputs themselves have working examples.

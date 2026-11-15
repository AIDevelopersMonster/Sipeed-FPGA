# Tang Primer 25K — Processor Research Laboratory

**Board:** Sipeed Tang Primer 25K + Dock  
**Focus:** RISC-V processor architectures, SoC integration, memory, buses, and reproducible FPGA measurements.

> **Статус на 2026-11-15: PAUSED — ждём модуль SDRAM.** Разработка Tang Primer 25K + Dock остановлена по решению оператора после двух суток экспериментов. Новые сборки и прошивки не объявляются рабочими без BOARD PASS.

## Подтверждённый результат и ограничения на момент остановки

| Направление | Статус |
| --- | --- |
| JTAG: плата GW5A-25A обнаружена | **PASS** |
| CLI: загрузка FPGA-конфигурации в volatile SRAM | **PROGRAM PASS** (не означает работу её функций) |
| PMOD: двухразрядный семисегментный индикатор | **BOARD PASS** — наблюдалась смена показаний |
| HDMI / DVI, включая сторонние примеры | **Нет подтверждённого изображения** |
| USB Host клавиатура → UART | **NOT TESTED / BOARD PASS отсутствует** |
| UARTTX / UART-терминал | **BOARD PASS отсутствует** |
| RISC-V / PiKoSoL 25K | **NOT IMPLEMENTED / BOARD PASS отсутствует** |
| Заводская рабочая конфигурация FPGA | **Восстановление не подтверждено** |
| Внешняя SDRAM | **Модуль отсутствует; ожидание поставки** |

**Правило сохранения:** рабочими считать только конкретные проверенные на плате варианты с доказательствами. PREPARE PASS, BUILD PASS и успешная отправка .fs через CLI не равны BOARD PASS. Непроверенные и нерабочие сборки не представлять как готовые релизы.

**Условие возобновления:** получение и проверка SDRAM. После этого начать с воспроизводимой базовой аппаратной конфигурации и отдельной проверки UART; лишь затем USB Host, видеовывод и PiKoSoL. SDRAM сама по себе не устраняет возможные ошибки UART/USB, поэтому результаты проверять независимо. Обновление инструментария и новая прошивка — возможная гипотеза при возобновлении, а не подтверждённое исправление.

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

**State:** PAUSED (2026-11-15), pending SDRAM. Only the seven-segment PMOD demo has a recorded functional BOARD PASS; other interfaces remain unconfirmed.

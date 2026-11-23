# Sipeed Tang Nano 9K — с чего начать?

**FPGA GW1NR-9C · 27 МГц · Verilog · RISC-V · HDMI · UART · SD**

Вместо поиска по сотням файлов выберите маршрут:

## 1. Хочу запустить — без компилятора
**[Начните здесь: пошаговый запуск PiKoSoL v0.2.0](START_HERE_RU.md)**

USB-C → [WebUSB Loader](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-loader/) → временная SRAM → [Web Serial](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-control/) → `HELP`, `INFO`, `LED 1`, `GFX`.

[Проверенная прошивка](https://github.com/AIDevelopersMonster/Sipeed-FPGA/releases/tag/pikosol-v0.2.0) — **BOARD PASS 23.10.2026**, PicoRV32 + UART + HDMI 640×480.

## 2. Хочу научиться создавать схемы FPGA
**[Дорожная карта: от LED до RISC-V](ROADMAP_RU.md)**

- [LAB-00 — первая самостоятельная схема на Verilog](examples/00-led/README.md): 27 МГц, 6 светодиодов, тестбенч, Gowin CLI, только SRAM. **Новый кандидат: PREPARED, пока НЕ BOARD PASS.**
- [LAB-02 — PicoRV32 и управление LED из HTML](docs/lab02/README.md): **BOARD PASS**.
- [LAB-04 — PiKoSoL: CPU, UART, HDMI](docs/lab04/README.md): **BOARD PASS**.
- [SPI и microSD](examples/peripherals/README.md): отдельные лаборатории с разными уровнями готовности.

## 3. Хочу изучить проверенные разработки

| Разработка | Что демонстрирует | Проверка |
| --- | --- | --- |
| [PiKoSoL v0.2.0](docs/lab04/README.md) | PicoRV32, HDMI, UART, LED | BOARD PASS, [прошивка опубликована](https://github.com/AIDevelopersMonster/Sipeed-FPGA/releases/tag/pikosol-v0.2.0) |
| [NEORV32 LAB-06.1](02-NEORV32/README.md) | Альтернативный RISC-V, UART, LED | Ограниченный BOARD PASS; сравнительные замеры ещё не сделаны |
| [Pong RGB](games/pong-rgb/README.md) | Игра на Verilog без CPU | BOARD PASS; публичной .fs пока нет |
| [Breakout RGB](games/breakout-rgb/README.md) | Игра на Verilog без CPU | BOARD PASS, [релиз с .fs](https://github.com/AIDevelopersMonster/Sipeed-FPGA/releases/tag/konsol-breakout-rgb-v0.1.0) |
| [SD-01…08](boards/tang-nano-9k/experiments/README.md) | SPI, секторы SD, FAT32 | Разные статусы; смотрите протокол конкретной лаборатории |
| [PSRAM LAB-07](boards/tang-nano-9k/experiments/psram07/README.md) | Изучение памяти | Исследовательская работа |

**[Подтверждённые сборки и SHA256](VERIFIED_BUILDS.md)** · [Полный технический каталог прежнего README](docs/PROJECT_CATALOG.md) · [Исследовательские статьи](docs/education/README.md).

## Правило результатов

PREPARED ≠ RTL PASS ≠ Gowin BUILD PASS ≠ STA PASS ≠ SRAM Program PASS ≠ BOARD PASS. Новая сборка проверяется независимо. В раздел рабочих релизов попадают только действительно проверенные прошивки. Все учебные загрузки — **только в энергозависимую SRAM**, без записи конфигурационной Flash.

[← Все платы и проекты Sipeed FPGA](../README.md)

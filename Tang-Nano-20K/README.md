# Tang Nano 20K — LiteX / VexRiscv: BIOS, UART, SDRAM и RISC-V программы

**Вы нашли главный каталог проекта Tang Nano 20K.** Ниже: зачем это исследование, что уже работает на реальной плате и как повторить опыт самостоятельно. Все рабочие файлы собраны в подразделах этой папки.

> **Главное:** мы изучаем **заводскую** FPGA-систему **LiteX + VexRiscv_Min** на **Sipeed Tang Nano 20K**, а затем пишем и исполняем **собственные программы RISC-V из SDRAM**. Мы пока **не синтезировали новую FPGA-прошивку** для этой платы. Конфигурационную Flash не меняем.

**[Текущее состояние LiteX](PROJECT_STATE.md)** · **[Примеры Tang Nano 20K](Examples/README.md)** · **[Сторонние SoC — ThirdParty](ThirdParty/README.md)** · **[Z80 + CP/Mish: подтверждённый запуск](ThirdParty/Z80/README.md)**.

Следуем принятому порядку: **закрываем шесть уже определённых контрольных проверок LiteX** без расширения исследований; затем выпускаем **прикладные примеры работы платы**, а не следующие лаборатории ради лабораторий. Результаты каждой физической проверки сохраняем в GitHub, чтобы развитие проекта не зависело от памяти отдельных диалогов.

**[Завершающая проверка LiteX: 6 пунктов, скрипты и критерии PASS](LiteX-Closeout/README.md)** · **[Браузерная диагностика (только чтение)](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab20/closeout/)** · [Примеры HDMI/SD после закрытия](Examples/README.md).

## Начать за 5 минут

**[BIOS / LiteX — подробный справочник, команды и эмулятор](BIOS/LiteX/README.md)** · **[Понятное объяснение проекта — с нуля](START_HERE_RU.md)** · **[Как повторить LAB-20.6 на Windows (пошагово)](REPRODUCE_LAB20_6_RU.md)** · **[Частые вопросы](FAQ_RU.md)**

## Карта лабораторий

| Этап | Что мы исследовали | Файлы | Аппаратный результат |
|---|---|---|---|
| **LAB-20.0 — Заводская система** | Встроенный BIOS, процессор, доступная SDRAM и UART | **[BIOS/LiteX](BIOS/LiteX/README.md)** · [стенд](00-Factory-LiteX/README.md) | **PASS**: LiteX BIOS на COM25, VexRiscv_Min 48 МГц, память |
| **LAB-20.4 — ROM Explorer** | Считали ROM BIOS, нашли повторение адресов, разобрали машинный код RV32I | [04-ROM-Explorer](04-ROM-Explorer/README.md) | **PASS**: окно 128 КиБ, уникальный образ 32 КиБ |
| **LAB-20.5 — UART / CSR** | Выяснили, как CPU управляет UART через регистры, проверили 7 адресов | [05-UART-CSR](05-UART-CSR/README.md) | **PASS**: значения на реальной плате |
| **LAB-20.6 — Собственная программа** | Написали RV32I-код, загрузили 740 байт в SDRAM, исполнили и вывели отчёт | **[06-RV32-RAM-Diagnostics](06-RV32-RAM-Diagnostics/README.md)** | **PASS**: чтение 740/740 байт + исполнение на VexRiscv |
| **LAB-20.7 — Прерывания** | Собственный обработчик аппаратного IRQ | Пока план | **NOT TESTED** |

## Главное аппаратное достижение: собственная программа RISC-V заработала

```text
litex> boot 0x40010000
Executing booted program at 0x40010000
--============= Liftoff! ===============--
PiKoSoL LAB20.6 RAM-only snapshot BEFORE UART output
TXEMPTY    = 0x00000001
EV_PENDING = 0x00000001
EV_ENABLE  = 0x00000003
TXEMPTY_AFTER_PRINT = 0x00000000
LAB20.6 HOLD - press physical RESET to return to BIOS
```

Это фрагмент **реального отчёта Tang Nano 20K от 8 ноября 2026 года**, не симуляция. До собственной печати программа считала `TXEMPTY=1` (очередь UART пуста), после печати — `TXEMPTY=0`. Мы экспериментально показали, как диагностический вывод сам меняет измеряемое состояние UART.

Полный неизменённый вывод: **[аппаратный протокол LAB-20.6](06-RV32-RAM-Diagnostics/RV32_HARDWARE_EXECUTION_PASS_2026-11-08.md)**.

## Что скачать и открыть

- **[Готовая программа RISC-V, 740 байт](06-RV32-RAM-Diagnostics/snapshot.bin)** · [ассемблерный исходник](06-RV32-RAM-Diagnostics/snapshot.S) · [загрузчик PowerShell](06-RV32-RAM-Diagnostics/upload.ps1).
- **[Запустить ROM Explorer v3.3 онлайн](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab20/rom-explorer/)** · [скачать автономный HTML](BIOS/LiteX/index.html) · [руководство](BIOS/LiteX/ROM_EXPLORER_GUIDE_RU.md).
- [ROM BIOS, уникальные 32 КиБ](04-ROM-Explorer/PiKoSoL_LAB20_ROM_32KiB.bin) · [реестр UART/CSR](05-UART-CSR/README.md).
- [Полная инструкция воспроизведения с командами для Windows](REPRODUCE_LAB20_6_RU.md).

## Схема эксперимента

```text
Windows + USB-UART 115200 (на нашем ПК COM25)
        | команды: mem_read / mem_write / boot
        v
Tang Nano 20K [заводская конфигурация LiteX]
        |-- CPU: VexRiscv_Min, RISC-V @ 48 МГц
        |-- ROM: заводской LiteX BIOS (только читаем)
        |-- UART: MMIO 0xF0003000 через Wishbone
        `-- SDRAM 0x40000000: наш код 0x40010000, данные 0x40011000
```

## Где лежали материалы раньше

Ранее файлы были разнесены между [docs/lab20](../docs/lab20/README.md), [docs/lab20/rom-explorer](../docs/lab20/rom-explorer/README.md) и [03-LiteX-VexRiscv/lab20-6-ram-diag](../03-LiteX-VexRiscv/lab20-6-ram-diag/README.md). **Все эти каталоги оставлены, чтобы прежние ссылки продолжали открываться.**

**Ограничение:** это результат работы на плате с **заводским LiteX BIOS**; если у вас другая FPGA-конфигурация и нет приглашения `litex>`, эта инструкция неприменима без адаптации. Ни одной проверки собственной FPGA-конфигурации, загрузки с SD, HDMI или входа в обработчик IRQ этими опытами не заявляется.

**English:** Research and reproducible experiments on the factory LiteX/VexRiscv_Min SoC of Sipeed Tang Nano 20K. Real hardware PASS for a 740-byte RAM-loaded RV32I program, UART MMIO measurements and FIFO self-observation. No custom FPGA bitstream and no Flash writes. See [reproduction guide](REPRODUCE_LAB20_6_RU.md).

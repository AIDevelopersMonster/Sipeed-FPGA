# LiteX BIOS — официальные ресурсы и наши источники

[← Справочник BIOS](README.md)

## Официальные проекты

| Ресурс | Зачем смотреть |
|---|---|
| **[LiteX — официальный GitHub](https://github.com/enjoy-digital/litex)** | Генерация SoC, шина Wishbone, память, CSR, интегрированный BIOS и build workflow |
| **[LiteX wiki](https://github.com/enjoy-digital/litex/wiki)** | Обзор технологии, установка, структура проекта; содержание может меняться |
| **[LiteX documentation](https://docs.litex-hub.org/)** | Документация экосистемы LiteX (доступность конкретных страниц следует проверять) |
| **[litex-boards](https://github.com/litex-hub/litex-boards)** | FPGA-board targets и параметры SoC для разных плат |
| **[Оригинальный target Tang Nano 20K](https://github.com/litex-hub/litex-boards/blob/6b8a5d35c03e408f738a9667c0497f31e25bf0b7/litex_boards/targets/sipeed_tang_nano_20k.py)** | Историческая FPGA-конфигурация, сопоставимая с заводским образом 2023 г. |
| **[VexRiscv](https://github.com/SpinalHDL/VexRiscv)** | Отдельное процессорное ядро, которое LiteX интегрирует как CPU |
| **[Sipeed Tang Nano 20K (официальная wiki)](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)** | Характеристики физической платы, интерфейсы, распиновка, инструменты |

## Зафиксированная версия, с которой сопоставлялся заводской BIOS

Заводской терминал сообщил `LiteX b05c3069`, BIOS `2023-03-13 17:09:37`. **Это сообщение о происхождении прошивки, а не независимое подтверждение точного полного git checkout всех библиотек**. Для реконструкции использованы исходники на соответствующем коммите:

- [LiteX commit `b05c3069`](https://github.com/enjoy-digital/litex/tree/b05c3069)
- [BIOS main](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/software/bios/main.c)
- [BIOS readline / ANSI prompt](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/software/bios/readline.h)
- [BIOS boot](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/software/bios/boot.c)
- [BIOS commands: memory](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/software/bios/cmds/cmd_mem.c)
- [BIOS commands: boot](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/software/bios/cmds/cmd_boot.c)
- [BIOS helper / dump bytes](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/software/bios/helpers.c)
- [LiteX UART core](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/cores/uart.py)

## Наше исследование

- [LAB-20 — начальный BIOS и проверка памяти](../../00-Factory-LiteX/README.md).
- [Заводской ROM, 32-КиБ образ](PiKoSoL_LAB20_ROM_32KiB.bin), [манифест](PiKoSoL_ROM_32KiB_manifest.json), [проверка четырёх зеркал](ROM_ALIAS_AUDIT.md).
- [Реконструкция CSR и `uart_init`](CSR_UART_LAB20_5.md), [реальные измерения UART](UART_CSR_HARDWARE_2026-11-07.md).
- [RV32I: наша программа, аппаратный PASS](../../06-RV32-RAM-Diagnostics/RV32_HARDWARE_EXECUTION_PASS_2026-11-08.md).
- [HTML ROM Explorer v3.3](index.html), [запуск модели](ROM_EXPLORER_GUIDE_RU.md).

## Статьи, опубликованные по материалам программы

- [LiteX BIOS: общая архитектура и опыт Tang Nano 20K, RU/EN](https://doi.org/10.5281/zenodo.23990004).
- [VexRiscv и VexRiscv_Min, RU/EN](https://doi.org/10.5281/zenodo.23991097).
- [Wishbone 32-bit, RU/EN](https://doi.org/10.5281/zenodo.23991663).

**Важно:** ссылки на GitHub `master` или «последнюю» версию показывают **современный** LiteX, который может отличаться от заводского BIOS 2023. Для аппаратной реконструкции используйте исторический коммит и реальные данные платы.

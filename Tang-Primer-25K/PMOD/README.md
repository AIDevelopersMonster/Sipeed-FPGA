# PMOD — Tang Primer 25K + Dock

## Фактическая комплектация — 5 типов PMOD

Подтверждено пользователем: **BTN (кнопки; в сообщении обозначено BIN), TF (microSD), LED, DT (DIGTUBE) и DVI**. Количество экземпляров каждого типа не уточняем. **Камеры OV5640 нет.** Отдельного PMOD GPIO нет и он не нужен.

| PMOD | Назначение | Статус |
| --- | --- | --- |
| BTN | Кнопки, GPIO input | **BOARD PASS** (в комплекте PMOD-01) |
| [TF](TF/README.md) | microSD, SPI | Имеется; NOT TESTED |
| LED | Светодиоды, GPIO output | **BOARD PASS** (PMOD-01) |
| DT / DIGTUBE | Цифровой индикатор | **BOARD PASS** (PMOD-01) |
| [DVI](DVI/README.md) | Видеовывод | Имеется; READY TO TEST |

[PMOD-01: аппаратный BOARD PASS и видео](PR25-PMOD-01_SRAM_PROGRAM_PASS_2026-11-13.md) · [YouTube](https://youtu.be/M-A6kIbpd1M)

## Очередность

1. Быстрый тест BTN, DT, LED: [официальный проект Sipeed](https://github.com/sipeed/TangPrimer-25K-example/tree/main/pmod_digitalTube-2bit). При USB-A слева, USB-C справа и PMOD снизу: BTN слева, DT по центру, LED справа ([уточнение порядка](https://github.com/sipeed/TangPrimer-25K-example/issues/17)).
2. Проверка DVI (тестовая картинка).
3. Проверка TF/microSD (чтение через SPI).
4. USB-A Dock (USB Host при наличии и проверке RTL).
5. Интеграция контроллеров, процессоров, ОС и игр.

[Практический план](../QUICK_START_PLAN.md).

Не использовать неподтвержденную распиновку. FPGA сначала программировать в SRAM. Отчёты SIM / BUILD / STA / BOARD PASS фиксируются только после соответствующих проверок.

**SDRAM:** модуль TANG SDRAM V1.3 заказан, ожидается ориентировочно через две недели. Это не PMOD, испытания PMOD не задерживаются.

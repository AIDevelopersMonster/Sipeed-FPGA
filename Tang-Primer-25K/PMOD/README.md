# PMOD — Tang Primer 25K + Dock

## Проверенный воспроизводимый пример

**[PR25-PMOD-01: BTN + DT + LED — исходники, проект Gowin, оригинальная прошивка и протокол BOARD PASS](BTN-DT-LED/README.md)**. В этой папке теперь есть сценарий загрузки закреплённого оригинала Sipeed, а не только описание результата. На плате проверен общий проект из трёх модулей; их изолированные версии не проверялись.

## Фактическая комплектация — 5 типов PMOD

Подтверждено пользователем: **BTN (кнопки; в сообщении обозначено BIN), TF (microSD), LED, DT (DIGTUBE) и DVI**. Количество экземпляров каждого типа не уточняем. **Камеры OV5640 нет.** Отдельного PMOD GPIO нет и он не нужен.

| PMOD | Назначение | Статус |
| --- | --- | --- |
| [BTN](BTN-DT-LED/README.md) | Кнопки, GPIO input | **BOARD PASS** (в составе PMOD-01) |
| [TF](TF/README.md) | microSD, SPI | Имеется; NOT TESTED |
| [LED](BTN-DT-LED/README.md) | Светодиоды, GPIO output | **BOARD PASS** (в составе PMOD-01) |
| [DT / DIGTUBE](BTN-DT-LED/README.md) | Цифровой индикатор | **BOARD PASS** (в составе PMOD-01) |
| [DVI / HDMI + AUDIO](DVI/WORKING_PROJECTS_RU.md) | Видеовывод и HDMI-звук | **BOARD VIDEO+AUDIO PASS**: A2600Nano v2.5 Golden и PR25-13; **VIDEO PASS**: Brus-16 и PR25-08..10 (в них звук не подтверждён) |

[PMOD-01: аппаратный BOARD PASS и видео](PR25-PMOD-01_SRAM_PROGRAM_PASS_2026-11-13.md) · [YouTube](https://youtu.be/M-A6kIbpd1M)

## Подтверждённые HDMI + звук и оригиналы

**[Реестр реально работающих PMOD DVI/HDMI проектов](DVI/WORKING_PROJECTS_RU.md)**: [A2600Nano v2.5 Golden](https://github.com/MiSTle-Dev/A2600Nano/releases/tag/v2.5) — VIDEO+AUDIO BOARD PASS; [наша PR25-13](../Examples/PR25-13-A2600-SDC-DUTY50/WORKING_FIRMWARE.md) — VIDEO+AUDIO BOARD PASS; [Brus-16 SFX](https://github.com/Papr1ka/brus16/releases/tag/sfx) — VIDEO BOARD PASS, звук не услышан. Испытания Sipeed HDMI/SVO и Arcade MCR2 не дали изображения, **но это не результат всего DVI-интерфейса**.

## Очередность

1. Быстрый тест BTN, DT, LED: [официальный проект Sipeed](https://github.com/sipeed/TangPrimer-25K-example/tree/main/pmod_digitalTube-2bit). При USB-A слева, USB-C справа и PMOD снизу: BTN слева, DT по центру, LED справа ([уточнение порядка](https://github.com/sipeed/TangPrimer-25K-example/issues/17)).
2. **DVI уже имеет аппаратный VIDEO+AUDIO PASS** в Golden A2600Nano и PR25-13; будущая задача — выделение интерфейса для PiKoSoL, а не повторное доказательство наличия изображения.
3. Проверка TF/microSD (чтение через SPI).
4. USB-A Dock (USB Host при наличии и проверке RTL).
5. Интеграция контроллеров, процессоров, ОС и игр.

[Практический план](../QUICK_START_PLAN.md).

Не использовать неподтвержденную распиновку. FPGA сначала программировать в SRAM. Отчёты SIM / BUILD / STA / BOARD PASS фиксируются только после соответствующих проверок.

**Статус программы:** PAUSED до поступления SDRAM, после его получения проект возобновляется. Сохранение проверенных примеров не означает новых аппаратных испытаний сейчас.

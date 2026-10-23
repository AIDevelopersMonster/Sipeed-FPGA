# LAB-04 — PicoRV32 HDMI Computer / Tang Nano 9K

**Первый экран через штатный HDMI, клавиатура через ПК и встроенный USB-UART, шесть штатных LED. Без пайки.**

- **[Полное руководство LAB-04 (RU)](../../01-PicoRV32/lab04/README_RU.md)** — установка, назначение каждого файла, команды PowerShell, карта HDMI, UART и LED, пределы проверки.
- **[HDMI Smoke RTL](../../01-PicoRV32/lab04/rtl/lab04_hdmi_smoke_top.v)** — самостоятельная тестовая таблица и LED 0…6, пока без процессора.
- **[PicoRV32 + HDMI top](../../01-PicoRV32/lab04/rtl/lab04_cpu_hdmi_top.v)** — процессорная система и видеотерминал.
- **[Исходный текст прошивки](../../01-PicoRV32/lab04/firmware/lab04_boot.S)** — команда `count 0..6` управляет шестью LED через MMIO, `one 1..6` включает отдельный LED.
- **[Официальный видеопример Sipeed](https://github.com/sipeed/TangNano-9K-example/tree/c3b795799f23de91982be52db4273a8eea100cdb/picotiny)** — источник шейдера тесткарты, TMDS, терминала и clock IP, закреплённый SHA.

## Статус

**SOURCE/MODEL PASS:** 235 рабочих RV32I слов, 7 тестов ISA-модели и 6 статических проверок, включая командную грамматику и LED MMIO. **RTL UART TB и Gowin/STA/HDMI BOARD:** `PENDING` до фактических тестов. Не заявляется пиксельный framebuffer, USB-host клавиатура, графическая ОС или программирование FPGA из браузера.

Два варианта `-Mode Smoke` (без CPU) и `-Mode CPU` (процессор + видеовывод) специально разделены, чтобы отличать отказ HDMI-канала от отказа SoC. Сборка использует отдельную staging-копию в игнорируемом `01-PicoRV32/lab04/build` и не трогает LAB-03.

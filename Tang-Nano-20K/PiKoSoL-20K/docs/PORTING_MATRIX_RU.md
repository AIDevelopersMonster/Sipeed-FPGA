# Перенос PiKoSoL 9K → PiKoSoL-20K: функциональная матрица

| Источник/подсистема 9K | Решение для 20K | Статус |
|---|---|---|
| `firmware/lab04_boot.S`, парсер строк/HELP/INFO/редактор/история | Переписаны как переносимый `pikosol_shell.c/.h`, без 9K адресов | Реализовано, host test |
| Два программных объекта A/B, перемещение, цвет, SIZE | Два объекта в RAM, **один выбранный** отображается через V201 | Реализовано, host test |
| `lab04_cpu_soc.v`, PicoRV32, 16К ROM/1К RAM | VexRiscv+LiteX; standalone SDRAM-код и собственный startup/stack | RV32 cross build, hardware TBD |
| 9K LED `0x20000000`, активные низкие LED | Не переносим адрес; для 20K LED будущий отдельный LiteX peripheral/pin audit | Нет в EX20-05.16 |
| 9K UART MMIO `0x20000010/18/1C` | LiteX UART CSR (на LAB-20.6 был `0xF0003000`; EX20-05.16 проверить по csr.csv) | Драйвер готов, board TBD |
| `lab04_video_cmd_cdc.v`, 9K MMIO `0x20000100...13C` | В v0.1 **не использовать**. Wishbone V201 `0xB1000000` с рамочным COMMIT | Программная интеграция |
| `lab04_graphics_osd.v`: A+B, outline/checker, 640x480, BGR888 | Планируем расширение графики 20K отдельным слоем; V201 остаётся единственным прямоугольником 1280x720 RGB888 | Отложено |
| `lab04_console_osd.v`: 32×76 ring BRAM, ASCII, 8×12 font, TERM/GFX | Идея и текстовые управляющие символы переносимы; **AXI-stream 640×480 не подключать напрямую к V201** | Спецификация TERM |
| `lab04_tty_byte_cdc.v`: lossless req/ack 8-bit | Кандидат на адаптацию в новой конфигурации; пересмотреть сбросы, STA, двойную синхронизацию | Только исходный 9K код |
| `lab04_uart_tty_bridge.v`, UART TX/video tap | На 20K UART пока обслуживает CPU; экранный TERM получит только CPU TX, без дублирующего host echo | План |
| `lab04_font_8x12.hex`, BRAM шрифта | Возможный ASCII font ROM в новом pixel-домене, проверить лицензию/разметку | План |
| 9K PLL/HDMI/constraints | Не переносить: сохраняется proven `video_hdmi_bridge.v` 20K и его штатная TMDS/PLL/тайминги | **Заморожено** |

## Реальный V201 регистровый ABI (байтовые смещения)

`+0x00` ID=`0x56323031`; `+0x04` BG=`0x00RRGGBB`; `+0x08` XY=`{Y16,X16}`; `+0x0C` WH=`{H16,W16}`; `+0x10` RECT RGB; `+0x14` STATUS(bit0 BUSY); `+0x18` COMMIT(write 1); `+0x1C` VERSION.

Каждая транзакция — word-aligned 32-bit full-word Wishbone, где LiteX `bus.adr` измеряется в словах, а ядро принимает байтовое смещение. Перед записью проверять `V201`; запрещено обращаться к новым регистрам TERM на текущем битстриме. Перенос старого ROM бинарно невозможен: иной процессор/ABI старта, адреса MMIO, CSR UART, разрешение и набор видеоопераций.

## Границы доказательств

- LAB-04.3.2 v0.2.0-alpha: исходники и модель, без полного подтверждения RTL/board.
- LAB-04.3.1 v0.1.8b1: проверенная аппаратная предыдущая основа 9K.
- EX20-05.16: user-observed physical VexRiscv+HDMI+Wishbone ID/rect/position, но не наш shell.
- P20-SHELL-01: host test + C cross build; никакой аппаратной приёмки текущего приложения.

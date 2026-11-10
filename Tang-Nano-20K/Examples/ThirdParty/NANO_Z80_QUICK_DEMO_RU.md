# TP20-01 — nano-Z80 на Tang Nano 20K: короткая демонстрация без SD

**Статус:** демонстрационный протокол подготовлен, **BOARD NOT TESTED**. Сторонний образ *заменяет заводской LiteX во временной FPGA SRAM*. После отключения питания при неизменённой Flash должен восстановиться заводской образ; это надо подтвердить фактически.

## Подключение

Только штатный USB-C платы к ПК и HDMI к монитору. На борту Tang Nano 20K имеется встроенный USB→UART; дополнительный USB–TTL к GPIO не требуется. Запасной внешний USB–TTL допустим как лабораторный инструмент, но тогда надо отдельно проверить pin mapping и уровни 3.3 V; соединять внешние RX/TX с уже используемым каналом без схемы нельзя.

Терминал COM: **115200, 8N1, flow control NONE**, отправка строки с **CR** (не только LF). COM25 был нашим портом заводского LiteX, но после переподключения номер может измениться.

## Шаг 0 — сохранить контрольную точку

Снять лог заводского LiteX BIOS и имя текущего COM-порта; удостовериться, что это именно Tang Nano 20K, что HDMI и USB-C подключены. Закрыть все приложения, использующие COM. Сохранить известный путь восстановления заводского LiteX; не записывать Flash.

**PLL:** nano-Z80 требует внешние PLL outputs: O0 = **25.175 MHz** (пиксельные/CPU такты), O1 = **12 MHz**. Это отдельная конфигурация внешнего генератора платы. Её нельзя смешивать с программированием FPGA bitstream. Прежде чем менять частоты, зафиксировать прежние значения, проверить синтаксис команд для текущего firmware USB-programmer, не использовать постоянное сохранение `-s` на первом опыте без проверенного восстановления. Если PLL уже настроен, ничего не менять.

Авторская процедура: открыть serial terminal USB-programmer, затем `Ctrl+X`, `Ctrl+C`, Enter; `pll_clk O0=25175K -s`, `pll_clk O1=12M -s`, `reboot`. **Эти команды меняют настройки генератора и могут переживать FPGA SRAM-перезагрузку.** На нашей плате их выполнять только после проверки существующих настроек и способа возврата; если недоступно — пометить BLOCKED_PLL, а не применять вслепую.

## Шаг 1 — получить файл автора

URL: https://github.com/venomix666/nano-z80/releases/latest/download/nano-z80.fs

Из PowerShell внутри `Tang-Nano-20K/Examples/ThirdParty`:

```powershell
Set-Location C:\GitHub\Sipeed-FPGA\Tang-Nano-20K\Examples\ThirdParty
.\get-nano-z80.ps1
```

Скрипт сохраняет `downloads/nano-z80.fs`, создаёт текстовый SHA256-файл, проверяет непустой файл, **не перепрошивает плату**.

Для загрузки **только в SRAM** (после проверки PLL и программатора):

```powershell
.\get-nano-z80.ps1 -LoadSRAM
```

Скрипт выполняет только `openFPGALoader -b tangnano20k <path>` **без `-f`** и без записи конфигурационной Flash. Перед этим он требует подтверждение оператором. Если CLI недоступен, вызывайте `openFPGALoader -b tangnano20k .\downloads\nano-z80.fs` вручную. Не применять `-f`.

## Шаг 2 — открыть терминал и увидеть запуск

Ожидаемая строка из исходного `romcode/nano-z80.z80`:

```text
nano-Z80 monitor v0.3
Available commands:
...
Ready
```

ROM печатает символы **одновременно** в UART и на HDMI TTY, поскольку `print_char` вызывает `uart_tx` и `tty_write`. Поэтому включить запись терминального лога и сфотографировать HDMI.

При отсутствии HDMI изображения не менять исходники в первом заходе: сначала подтвердить PLL, файл .fs, статусы JTAG и UART. При отсутствии ввода проверить CR, скорость 115200 и отсутствие второй программы, захватившей COM.

## Шаг 3 — короткий набор команд (вводим с ПК, завершаем Enter/CR)

Команды монитора (без пробелов, кроме показанных в выводе автора):

| Команда | Ожидаемое назначение | Граница безопасности |
|---|---|---|
| `M0000,0040` | Показать 64 байта адресного пространства с 0000 — область boot ROM при первоначальном отображении | Только чтение. Значения не предсказаны без фиксации образа. |
| `I7F,01` | Прочитать один раз порт 0x7F — текущий номер IO bank | Только чтение. После загрузки ROM ожидается значение одного из банков, но не обещаем ноль. |
| `O7F,00` | Выбрать IO bank 0 | Меняет регистр выбора периферии, допустимо для LED-демо. |
| `O00,3F` | Записать 0x3F в LED register 0x00 при выбранном bank 0 | Изменение onboard LED; полярность инвертирована, не обещаем определённое состояние «все горят». |
| `O00,00` | Вернуть LED-регистр в 0x00 | Визуальный обратный переход. |

Почему команды: декодер `src/addr_decoder.v` использует порт 0x7F как выбор IO-bank, bank 0 управляет LED. В `src/nano-z80_top.v` выдача на 6 LED физически инвертирована. ROM parser поддерживает `M...`, `I...`, `O...`. Не запускать `B`, `F`, `L` без SD, `J` без собственной программы, `W` без карты памяти и `T` из-за неполноты readback теста.

**Примечание:** `I7F,01` проходит через monitor_port_in с портом 0x7F и длиной 1. Регистр читается встроенным decoder. После `O7F,00` удобно повторить `I7F,01` и увидеть ноль.

## Приёмка видео

Показать одним непрерывным фрагментом: плата → подключение USB-C/HDMI → терминал ПК → ROM banner на HDMI → `M0000,0040` и `I7F,01` → `O7F,00`/`O00,3F`/`O00,00` и реакция LED. **Этого достаточно для учебной демонстрации реального Z80, ROM-монитора, UART и HDMI.** При наличии времени показать структуру `romcode/`, `src/video/`, `src/UART/`, `src/sdram_z80.v` на GitHub.

## Финальная квитанция

```text
PROJECT: TP20-01 nano-Z80
SOURCE: https://github.com/venomix666/nano-z80
UPSTREAM_COMMIT:
UPSTREAM_RELEASE:
BITSTREAM_SHA256:
FPGA_BOARD: Sipeed Tang Nano 20K
COM_PORT:
PLL_BEFORE:
PLL_AFTER:
PROGRAM_COMMAND: openFPGALoader -b tangnano20k downloads/nano-z80.fs
FLASH_WRITES: NO
UART_ROM_BANNER: PASS / FAIL
HDMI_ROM_BANNER: PASS / FAIL
ROM_DUMP: PASS / FAIL
IO_BANK_READ: PASS / FAIL
LED_TOGGLE: PASS / FAIL
FACTORY_LITEX_RESTORED_AFTER_POWER_CYCLE: PASS / FAIL / NOT_TESTED
OVERALL: BOARD PASS / PARTIAL / FAIL / BLOCKED
LOGS/PHOTOS:
NOTES:
```

Нельзя объявлять BOARD PASS, пока оператор не выполнил физическую проверку. Если на экране отсутствует часть вывода, а UART работает — это диагностически ценный PARTIAL; не надо сразу переписывать HDMI-контроллер.

## Источники

- [README и образ nano-z80.fs](https://github.com/venomix666/nano-z80)
- [ROM Monitor](https://github.com/venomix666/nano-z80/blob/main/romcode/nano-z80.z80)
- [Ввод UART / USB](https://github.com/venomix666/nano-z80/blob/main/romcode/read.z80)
- [Дублирование UART / HDMI](https://github.com/venomix666/nano-z80/blob/main/romcode/print.z80)
- [Выбор IO и доступ к портам](https://github.com/venomix666/nano-z80/blob/main/src/addr_decoder.v)
- [UART RTL](https://github.com/venomix666/nano-z80/blob/main/src/UART/uart.v)
- [HDMI TTY RTL](https://github.com/venomix666/nano-z80/blob/main/src/video/video.v)

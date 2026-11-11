# TP20-01 nano-Z80 — ROM Monitor BOARD PASS — 2026-11-10

**Статус:** оператором подтверждено выполнение монитора Z80 и команды чтения ROM на физической Tang Nano 20K. Завершён первый минимальный аппаратный показ без SD и внешней клавиатуры. **Не утверждается**, что проверены все периферийные блоки или CP/M / FUZIX.

## Подтверждённое оборудование и ПО

- FPGA: Sipeed Tang Nano 20K, GW2AR-18C family, JTAG ID `0x0000081B`; конфигурирование **только в SRAM**.
- Bitstream: upstream [venomix666/nano-z80](https://github.com/venomix666/nano-z80), `nano-z80.fs` размер **7 262 008 байт**; SHA-256 `8DD5274B4DA2E85D8877B10D62494802BAE59541B8C964751B5341E1AB055770`.
- Программатор: Gowin `programmer_cli.exe`; `--device GW2AR-18C --run 2 --fsFile ... --cable-index 1`; **SRAM PROGRAM CLI EXIT 0**, подтверждены `User Code: 0x0000FB41`, `Status Code: 0x00006020`.
- BL616/MS5351: O0 **25 175 000 Hz** [ EN], O1 **12 000 000 Hz** [ EN], O2 [DIS]; изменения выполнены командой `pll_clk` **без `-s`**, в сохранённую Flash не записывали.
- Подключение: USB–UART/COM25 на ПК оператора, 115200 8N1, HDMI к монитору. Без SD, nanoComp и внешней USB-клавиатуры.
- **Кнопка аппаратного перезапуска на данном стенде — S2** (оператор подтвердил). Нажатие **S1 не вызвало реакции**. Ранее в нашем сценарии ошибочно указывалась S1.

## Дословный аппаратный вывод оператора

После нажатия S2 оператор передал:

```text
nano-Z80 monitor v0.3

Available commands:
MAAAA,NNNN  - display NNNN bytes of memory at addresss AAAA
WAAAA,DD    - write data DD to address AAAA
JAAAA       - jump to address AAAA
OPP,DD      - write data DD to IO port PP
IPP,NN      - read NN bytes from IO port PP
B           - boot CP/M from the SD card
L           - load CP/M image from the SD card without booting
F           - boot Fuzix from the SD card
T           - run memory test
Ready
M0000,0040
0000: 31 FF FF CD D3 01 21 61 04 CD 3E 02 21 2A 06 CD  1▒▒▒▒.!a.▒>.!*.▒
0010: 3E 02 21 FF FE 06 00 18 05 21 00 FF 06 00 CD A0  >.!▒▒....!.▒..͠
0020: 02 CD 6B 02 FE 7F 28 59 FE 08 28 55 77 23 04 FE  .▒k.(Y▒.(Uw#.▒
0030: 0D 20 EB CD 34 02 3A 00 FF 21 76 00 E5 FE 4D CA  . ▒▒4.:.▒!v.▒▒M▒

Ready
```

Четыре строки × 16 байт = **64 байта**. Структура соответствует рабочему Z80 ROM monitor: первый opcode `31 FF FF` = `LD SP,0xFFFF`; `CD D3 01` = `CALL 0x01D3` (little endian); `21 61 04` = `LD HL,0x0461`. Соответствие общей структуре видно в [romcode/nano-z80.z80](https://github.com/venomix666/nano-z80/blob/main/romcode/nano-z80.z80). Значения взяты из настоящего машинного вывода оператора, не из симуляции.

## Что подтверждено и что нет

| Проверка | Результат |
|---|---|
| JTAG идентификация платы | **BOARD PASS** |
| Загрузка готовой FPGA-конфигурации в SRAM | **BOARD PASS** (успешная команда конфигурирования; не означает отдельно PASS программы) |
| Внешние PLL O0 и O1 | **BOARD PASS для настройки/чтения BL616** |
| HDMI видео, текстовый экран и курсор | **BOARD PASS по наблюдению оператора** (не измерены EDID и временные характеристики) |
| Z80: исполнение кода ROM, баннер, цикл команд и `Ready` | **BOARD PASS** |
| UART: команда с ПК и получение дампа ROM | **BOARD PASS по присланному транскрипту** |
| Чтение 64 байт ROM (`M0000,0040`) | **BOARD PASS** |
| RAM / SDRAM полный тест, кэш, MMU во всех режимах | NOT TESTED |
| `I007F,0001`: чтение банка | NOT TESTED |
| `O007F,00`, `O0000,3F`, `O0000,00`: onboard LED | NOT TESTED |
| CP/M, FUZIX, SD, USB HID, sound, graphics modes | NOT TESTED |
| Возврат заводского LiteX после power-cycle **именно этого опыта** | NOT TESTED (были успешные возвраты в предыдущем EX20-01) |
| Запись FPGA config Flash | **Не производилась** |

**Итог:** `TP20-01 ROM MONITOR BOARD PASS` — узкая, но достоверная аппаратная приёмка CPU/ROM/UART и видеовывода, без преувеличения охвата функций SoC.

## Диагностические уроки

1. MobaXterm удерживал COM25: `Access denied` Windows устранён закрытием клиента, не заменой драйвера.
2. MS5351 исходно выдавал `[DIS]O0/O1/O2: 27000000`, поэтому nano-Z80 был без требуемого внешнего clock. Выходы были включены на 25.175/12 MHz **без `-s`**.
3. В скрипте наша regex-проверка ошибочно отвергала валидную запись `[ EN]` вместо `[EN]` — исправлено в [tp20-enable-pll-volatile.ps1](tp20-enable-pll-volatile.ps1).
4. На данной плате для сброса nano-Z80 работает **S2**, не S1; первичное описание оператора: голубой/синий экран сменился чёрным экраном с курсором, после S2 появился полноценный ROM Monitor.
5. Синтаксис IO-команд в исходном парсере: четыре hex-цифры адреса `O007F,00` и `I007F,0001`, несмотря на краткие шаблоны в banner. [ROM parser](https://github.com/venomix666/nano-z80/blob/main/romcode/nano-z80.z80).

## Следующий небольшой показ без внешней периферии

В уже работающем ROM Monitor после `Ready` отправить:

```text
I007F,0001
O007F,00
I007F,0001
O0000,3F
O0000,00
```

Это покажет I/O bank readback и реакцию onboard LED. **Результата от оператора ещё нет**, поэтому новые BOARD PASS для этих функций пока не присваиваются. Если что-то отличается — сохранить транскрипт и не утверждать PASS автоматически.

## Источники / воспроизводимость

- [Upstream nano-Z80](https://github.com/venomix666/nano-z80)
- [Наш минимальный сценарий](NANO_Z80_QUICK_DEMO_RU.md)
- [Наш Gowin SRAM-only скрипт](program-nano-z80-gowin.ps1)
- [Непостоянная настройка MS5351](tp20-enable-pll-volatile.ps1)
- [Разбор составных частей исходников](EXTENDED_ANALYSIS_RU.md)
- [Полная хронология диагностики](TP20-01_ACCEPTANCE_2026-11-10.md)

Состояние SOURCE-CHECKED остаётся для nano6502 и tangySOC; не переносить аппаратный результат nano-Z80 на эти независимые SoC.

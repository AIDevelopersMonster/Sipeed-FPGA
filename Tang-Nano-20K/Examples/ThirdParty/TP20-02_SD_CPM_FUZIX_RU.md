# TP20-02 — SD-карта nano-Z80: CP/Mish, FUZIX, работа через ПК

**Дата аудита:** 2026-11-10 · **Статус:** SOURCE CHECKED / SD BOARD NOT TESTED.
[Главная TP20](README.md) · [Справочник команд](NANO_Z80_ROM_MONITOR_COMMANDS_RU.md) · [ROM BOARD PASS](TP20-01_ROM_MONITOR_BOARD_PASS_2026-11-10.md)

## 1. Поддержка SD в оригинальном проекте

У Henrik Löfgren [venomix666/nano-z80](https://github.com/venomix666/nano-z80) есть полноценный контроллер SD и две ОС, загружаемые из ROM:

- **CP/Mish (CP/M 2.2)**: команда `B` в ROM, образ [nano-z80.img](https://github.com/venomix666/nano-z80/releases/latest/download/nano-z80.img), порт [David Given / cpmish](https://github.com/davidgiven/cpmish/blob/master/arch/nano-z80/README.md).
- **FUZIX**: команда `F`, отдельный образ [FUZIX-disk.img](https://github.com/venomix666/nano-z80/releases/latest/download/FUZIX-disk.img), [порт на Codeberg](https://codeberg.org/EtchedPixels/FUZIX/src/branch/master/Kernel/platform/platform-nano-z80). По README автора его размещают с секторным смещением `0x100000` (512 MiB) от начала карты, совместно с CP/M.
- **14 виртуальных дисков по 4 MiB**: диски `A:`–`N:` CP/Mish. В документации порта указано: по умолчанию форматирован только `A:`; остальные не форматировать для нашей первой демонстрации.
- **Доступные утилиты** в исходнике [arch/nano-z80/build.py](https://github.com/davidgiven/cpmish/blob/master/arch/nano-z80/build.py): `bbcbasic.com`, `asm.com`, `stat.com`, `copy.com`, `qe.com`, `mkfs.com`, `nanoterm.com` (XMODEM), `imgview.com`, `img160.com`, `img320.com`, утилиты цвета.
- **RTL SD контроллер**: [src/sdcard/sd_interface.v](https://github.com/venomix666/nano-z80/blob/main/src/sdcard/sd_interface.v), [src/sdcard/sd_rw.v](https://github.com/venomix666/nano-z80/blob/main/src/sdcard/sd_rw.v), [src/sdcard/sdcmd_ctrl.v](https://github.com/venomix666/nano-z80/blob/main/src/sdcard/sdcmd_ctrl.v); аппаратные команды CMD17/24, 512-байтовый буфер, типы SDv1/SDv2/SDHC, CRC7/CRC16. Режим SD не требует внешнего UART или USB-клавиатуры для работы с ROM.

Готовые `.img` — это **сырые образы диска**, а не файлы для копирования в папку FAT32. Их запись в физическую SD перезаписывает существующие сектора и данные. Сначала только скачивание, проверка и резервная карта.

## 2. Важнейшее условие нашего стенда: консоль CP/M через COM25

Исследованный [BIOS CP/Mish](https://github.com/davidgiven/cpmish/blob/master/arch/nano-z80/bios.z80) имеет начальный `ioconfig: db 0x81` — **CRT**, то есть ввод с внешней USB-клавиатуры и вывод на HDMI. У нас внешней USB-клавиатуры не будет. Сама работающая ROM-консоль на COM25 **не означает**, что после обычного `B` клавиатура ПК продолжит работать в CP/M.

Другой IOBYTE, `0x83`, выбирает встроенный UART A (USB-C / COM25) для ввода и вывода CP/M. Тогда управление и текст CP/M будут в MobaXterm, а HDMI не обязан дублировать вывод CP/M. Это ограничение штатного BIOS, а не неисправность.

В тексте README порта есть противоречие: `F833` в повествовании и `WF633,83` в примере. По исходникам `arch/nano-z80/boot.z80` (страница входа F6) и BIOS (17 переходов по 3 байта до `ioconfig`) адрес получается **F633**, так как F600 + 0x33 = F633. **Перед записью обязательно подтверждаем значение 81 чтением, иначе STOP.**

### План первого запуска (после подготовки отдельной SD)

На плате с проверенным ROM Monitor v0.3 и `Ready`:

1. Вставить подготовленную резервную microSD в штатный слот.
2. Прочитать регистры состояния SD (раздел 4).
3. Выполнить **`L`** — загрузить CP/M с SD в RAM без запуска. Если карта не отвечает, ROM `sd_wait` не имеет ограничения времени и может зависнуть; восстанавливать только S2.
4. После возврата `Ready`:

```text
MF633,0001
```

Ожидается `F633: 81`. **Если значение не 81 — остановиться, не выполнять W/J.** При 81:

```text
WF633,83
MF633,0001
JF600
```

`WF633,83` изменяет байт **в загруженной RAM**, не на SD и не во FPGA Flash. `JF600` передаёт управление CP/M; новое приглашение и команды должны появиться на **COM25**, а не обязательно на HDMI.

**Не начинать с `B`:** на штатном CP/M-образе по умолчанию выбрана CRT консоль; кроме того, при некорректном секторе загрузки `B` после `sd_boot` может перейти по неподготовленному адресу `BOOT_PAGE`.

## 3. Подготовка образов на Windows — без записи карты

Скрипт [prepare-tp20-sd.ps1](prepare-tp20-sd.ps1) скачивает `nano-z80.img` и по желанию FUZIX, проверяет кратность размера 512, сигнатуру `nano` у CP/M, вычисляет SHA-256 и записывает манифест. **Он не открывает физические диски, не изменяет SD/FPGA/Flash/PLL.**

```powershell
Set-Location C:\GitHub\TP20-ThirdParty
$URL = 'https://raw.githubusercontent.com/AIDevelopersMonster/Sipeed-FPGA/main/Tang-Nano-20K/Examples/ThirdParty/prepare-tp20-sd.ps1'
Invoke-WebRequest -Uri $URL -OutFile .\prepare-tp20-sd.ps1
.\prepare-tp20-sd.ps1
```

Для отдельного изучения FUZIX: `.\prepare-tp20-sd.ps1 -WithFuzix`. Пока выбираем **только CP/Mish**, чтобы быстро получить демонстрацию.

### Запись на резервную SD

Поскольку образ сырый, его нельзя просто скопировать через Проводник. Он должен быть поблочно записан на **отдельную пустую карту без нужных данных** через программу записи raw image (например, Raspberry Pi Imager → Use custom). Перед началом оператор выбирает карту по модели и ёмкости; должен иметь резервную копию. Не форматировать её в FAT32 после записи образа. **В нашем скрипте записи физических накопителей нет** — исключаем случайную потерю данных.

Не переносить команды записи FUZIX на произвольный диск Windows: offset 512 MiB относится к выбранной SD, а не к файлу. Для FUZIX сначала нужен отдельный согласованный сценарий с проверкой выбранного накопителя.

## 4. Проверка SD без записи и даже без запуска CMD17

Из `src/sdcard/sd_interface.v` при I/O-bank 3: `0x04` busy, `0x08` card_stat, `0x09` card_type. Команды только читают аппаратные состояния; `O007F,03` выбирает банковую группу, `O007F,00` возвращает её:

```text
O007F,03
I0004,0001
I0008,0001
I0009,0001
O007F,00
```

Смысл: `busy=0` значит свободен, но это **не гарантия наличия карты**. `card_stat=08` — состояние `READY` в FSM `sd_rw.v`. Тип: `0` UNKNOWN, `1` SDv1, `2` SDv2, `3` SDHCv2. Эти статусы ещё не подтверждены на нашей физической плате.

Не писать на порт `0x06` при SD-bank 3: это **строб CMD24 записи сектора**. Запись случайных значений может уничтожить данные. Не использовать `T` ROM-монитора — не полноценный тест RAM.

## 5. Учебная карта исходников

| Модуль | Содержание и интерес |
|---|---|
| [sd_interface.v](https://github.com/venomix666/nano-z80/blob/main/src/sdcard/sd_interface.v) | Банковый CPU I/O, sector LBA, 4 × 128 B byte-page, dual-port RAM |
| [sd_rw.v](https://github.com/venomix666/nano-z80/blob/main/src/sdcard/sd_rw.v) | SD init/FSM, CMD17/CMD24, 512 B, CRC16 |
| [sdcmd_ctrl.v](https://github.com/venomix666/nano-z80/blob/main/src/sdcard/sdcmd_ctrl.v) | Командная линия CMD, CRC7, тайм-ауты протокола |
| [romcode/sdcard.z80](https://github.com/venomix666/nano-z80/blob/main/romcode/sdcard.z80) | SD boot, сигнатура `nano`, чтение сектора и перенос в RAM |
| [romcode/fuzixboot.z80](https://github.com/venomix666/nano-z80/blob/main/romcode/fuzixboot.z80) | Загрузка FUZIX ядра, отдельный путь из SD |
| [CP/Mish bios.z80](https://github.com/davidgiven/cpmish/blob/master/arch/nano-z80/bios.z80) | Дисковый BIOS, IOBYTE/TTY/UART, ROM disable |
| [CP/Mish boot.z80](https://github.com/davidgiven/cpmish/blob/master/arch/nano-z80/boot.z80) | Заголовок загрузочного сектора и страницы RAM |

**Инженерный вывод:** исходники интересны для переноса идеи «SD state machine + sector buffer + CPU registers» в PiKoSoL/LiteX через новый Wishbone bridge. Код не переносить без проверки лицензий, CDC и совместимости с шиной.

## 6. Критерии нового аппаратного PASS

- Есть физическая microSD и документирован точный SHA-256 скачанного `nano-z80.img`.
- Карта распознаётся по `card_stat/card_type`.
- `L` завершает чтение, `MF633,0001` показывает `81`.
- `WF633,83`, `JF600` приводят к приглашению CP/M на COM25, команда `DIR` показывает диск `A:`.
- Успешность других дисков, FUZIX или файловых операций не утверждать, пока они не проверены.

**Текущий результат:** TP20-01 ROM Monitor BOARD PASS. TP20-02 SD / CP/M / FUZIX — SOURCE-CHECKED, BOARD NOT TESTED.


## 7. Подтверждённая подготовка образа на ПК оператора

Оператор запустил исправленный PowerShell-скрипт 2026-11-11. Фактическая квитанция:

```text
SCRIPT SYNTAX PASS
[OK] C:\GitHub\TP20-ThirdParty\downloads\nano-z80.img (4186112 bytes)
NAME=CPMISH
BYTES=4186112
SHA256=5B92105D34D0BCE698EA419F2342A4C213EAFAB064C06757A332FC050CF6FA81
SECTOR0_FIRST16=6E-61-6E-6F-00-00-00-01-0F-E0-F6-00-00-00-00-00
NANO_BOOT_SIGNATURE=YES
CPM BOOT SECTOR: source-LBA-bytes 00-00-00-01; page count 15; RAM page 0xE0; jump page 0xF6
DOWNLOAD PASS: images are files on your Windows PC only; your SD card has NOT been changed.
```

Итог: **HOST IMAGE DOWNLOAD + SIGNATURE PASS**, SD CARD WRITTEN = NO, FPGA SD READ = NOT TESTED, CP/M BOARD = NOT TESTED. Зафиксирован SHA-256 исходного файла для последующего контроля.

### Безопасная инвентаризация накопителей до записи

[tp20-sd-preflight.ps1](tp20-sd-preflight.ps1) — по умолчанию режим **только чтение**: проверяет SHA-256, размер и поля заголовка, перечисляет физические диски Windows по номеру, имени, интерфейсу, ёмкости и флагам System/Boot; сохраняет квитанцию в evidence. Не форматирует, не выбирает диск автоматически и не пишет данные в карту. Отдельный ключ -InstallImager устанавливает Raspberry Pi Imager через winget, но не записывает карту.

```powershell
Set-Location C:\GitHub\TP20-ThirdParty
$URL = 'https://raw.githubusercontent.com/AIDevelopersMonster/Sipeed-FPGA/main/Tang-Nano-20K/Examples/ThirdParty/tp20-sd-preflight.ps1'
Invoke-WebRequest -Uri $URL -OutFile .\tp20-sd-preflight.ps1
.\tp20-sd-preflight.ps1
```

Результат запуска на ПК оператора пока **не получен**. После определения именно резервной microSD записать образ вручную через GUI с проверкой записи и НЕ принимать предложение Windows отформатировать карту. Далее использовать план разделов 2 и 4.

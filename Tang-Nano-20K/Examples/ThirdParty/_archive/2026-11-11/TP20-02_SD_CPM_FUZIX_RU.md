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


## 8. Выбор карты под запись (Windows preflight)

Оператор предоставил реальный вывод `tp20-sd-preflight.ps1`:

```text
DISK #2 | NAME=Mass Storage Device | BUS=USB | GB=14,56 | BOOT=False | SYSTEM=False | PARTITION_STYLE=MBR | OFFLINE=False
   PARTITION #1 | LETTER=F | BYTES=15634792448
PREFLIGHT COMPLETED; PHYSICAL_DISK_WRITES=NO; BOARD_SD_TEST=NOT YET TESTED
EVIDENCE: C:\GitHub\TP20-ThirdParty\evidence\TP20_SD_PREFLIGHT_20261111_002628.txt
```

**Статус: TARGET-CANDIDATE IDENTIFIED / NO IMAGE WRITTEN YET.** Это не подтверждение, что Disk 2 остаётся тем же носителем после переподключения USB. Перед записью подтвердить модель и ёмкость выбранной microSD в GUI, исключить системные диски. Образ `C:\GitHub\TP20-ThirdParty\downloads\nano-z80.img` размер 4 186 112 байт, SHA256 `5B92105D34D0BCE698EA419F2342A4C213EAFAB064C06757A332FC050CF6FA81`, HEAD `6E-61-6E-6F-00-00-00-01-0F-E0-F6-00-00-00-00-00`.

**Дальше:** Raspberry Pi Imager → Use custom → `nano-z80.img` → microSD USB 16 ГБ → WRITE + VERIFY; Windows после записи не должна форматировать носитель. Затем карта в Tang Nano 20K; сохранить действующие MS5351 O0=25.175MHz и O1=12MHz, использовать S2. В ROM Monitor выполнить только безопасный набор `O007F,03`, `I0009,0001`, `I0008,0001`, `I0004,0001`, `O007F,00`. Ожидания SDHC: type `03`, FSM ready `08`, busy `00`. Эти признаки ещё требуют физической квитанции. Только после неё запуск `L` → `MF633,0001` и, при байте `81`, `WF633,83` → `JF600`.

**Важно:** эта квитанция не означает, что SD записана или ОС запущена. Отчёт GUI Verify, аппаратные регистры и приглашение CP/M — отдельные этапы.

## 9. Восстановление Z80 после полного отключения питания

**Физически подтверждённый принцип:** наше Gowin SRAM-only программирование теряется при power-cycle, и Tang Nano 20K стартует из сохранённой заводской конфигурационной Flash с LiteX. Поэтому перед продолжением CP/M нужно снова загрузить `nano-z80.fs` через Gowin (`--run 2`) и временно включить MS5351 O0=25.175MHz, O1=12MHz без `-s`. Внешняя Flash остаётся нетронутой. После этого **S2** перезапускает nano-Z80, а MobaXterm на COM25 115200 8N1 показывает ROM Monitor. Наличие подготовленной SD не влияет на необходимость восстановить конфигурацию FPGA.

Для повторяемости опубликован [restore-nano-z80-after-powercycle.ps1](restore-nano-z80-after-powercycle.ps1), последовательно вызывающий уже проверенные локальные скрипты загрузки SRAM и установки MS5351. Оператор вводит `SRAM` и `CLOCKS` отдельно; перед выполнением закрывает MobaXterm для освобождения COM25. Скрипт не программирует Flash или SD.

## 10. Диагностика: L вернул Ready, но F633 = 39 (не 81)

Фактический вывод ROM Monitor оператора:

```text
L
Ready
MF633,0001
F633: 39  9
Ready
```

**Статус: L RETURNED / BOOT IMAGE IN RAM NOT VERIFIED.** В upstream ROM-команде L непосредственно вызывается sd_boot, который может вернуть управление без явной ошибки при несовпадении сигнатуры `nano` в секторе 0. Поэтому возврат `Ready` не подтверждает правильного чтения и загрузки. Поле штатного CP/Mish BIOS `ioconfig: db 0x81` по исходнику находится за 17 переходами JP (0x33 байта) от BBASE=0xF600, то есть F633. Считанный 0x39 расходится с ожидаемым для этой сборки. **НЕ ИСПОЛЬЗОВАТЬ WF633,83 и JF600, пока карта не сверена с локальным образом.**

Следующие безопасные команды только чтения ROM Monitor:

```text
MFFFF,0001
ME000,0020
MF600,0040
MF800,0040
```

Для сравнения на Windows использовать [tp20-cpm-image-map.ps1](tp20-cpm-image-map.ps1) — без записи носителей он проверяет SHA-256 исходного `nano-z80.img` и печатает те байты, которые должны оказаться в RAM E000..FDFF после корректного L. Если начало RAM отличается от файла, первоочередная проверка — верно ли переписан RAW образ на microSD и корректно ли происходит секторное чтение (сигнатура `nano` в секторе 0), а не изменение BIOS вслепую.

## 11. balenaEtcher: ошибка источника до записи (2026-11-11)

Оператор показал скриншот Windows balenaEtcher с ошибкой при выборе `C:\GitHub\TP20-ThirdParty\downloads\nano-z80.img`: 

```text
Error opening source
Something went wrong while opening C:\GitHub\TP20-ThirdParty\downloads\nano-z80.img.
Error: (0 , h.requestMetadata) is not a function
```

**Стадия:** открытие исходного файла, до выбора носителя и начала Flash/Validation. Никакой проверки SD через Etcher пока не получено. Это сообщение совпадает с задокументированным upstream багом balenaEtcher, особенно v2.1.7 (версия конкретной установки оператора на скриншоте не видна): https://github.com/balena-io/etcher/issues/4672 . Пользователи сообщали, что https://github.com/balena-io/etcher/releases/tag/v2.1.6 открывает те же образы без сбоя.

**Порядок исследования без преждевременного перехода к RTL:** либо (A) записать через исправную Etcher 2.1.6 и получить Validation PASS, либо (B) записать Win32 Disk Imager и прочесть с физической SD первые 4 186 112 байт скриптом [tp20-sd-readback-verify.ps1](tp20-sd-readback-verify.ps1), сравнив SHA-256 с `5B92105D34D0BCE698EA419F2342A4C213EAFAB064C06757A332FC050CF6FA81`. При переподключении проверить действительный номер USB-карты по модели и ёмкости; не трогать системные диски. До подтверждения физического образа не менять RTL, не делать вывод о причине паттерна `00 39` в SRAM.

## 12. SD sector 0: first byte matches; sequential port 0x0A read does not (2026-11-11)

After the operator reimaged the card using Win32 Disk Imager and verified the write, the operator reported the following ROM Monitor output following the sector-0 read procedure:

```text
Ready
I000A,0010
6E000000000000000000000000000000
Ready
```

**Observation:** the first byte (`6E`) matches the known `nano` header, but the remaining 15 values returned through repeated port-0x0A reads are `00`, rather than the expected `61 6E 6F 00 00 00 01 0F E0 F6 00 00 00 00 00`. This is **NOT** SD SECTOR READ PASS and it does not prove the SD media are defective. The ROM `I` command performs repeated IN instructions to the same selected port. The RTL `sd_interface.v` implements an auto-incrementing accessor at port `0x0A`, separate from addressable 128-byte window `0x80–0xFF` (selected by port `0x07`).

**Next read-only isolation** (assuming the sector read already completed and page 0 selected):

```text
I007F,0001
I0004,0001
I0007,0001
I0080,0001
I0081,0001
I0082,0001
I0083,0001
I0084,0001
I0085,0001
I0086,0001
I0087,0001
I0088,0001
I0089,0001
I008A,0001
```

Expected 0x80..0x8A: `6E 61 6E 6F 00 00 00 01 0F E0 F6`. Do not issue `L`, `B`, `WF633,83`, or `JF600` before the read path is isolated. The expected state of port `0x7F` is bank `03`; port `0x04` busy `00`; port `0x07` page `00`. If any of those differs, stop and investigate state before interpreting the data.

**Conclusions deliberately withheld:** no proof yet that sector contents are correctly transferred to FPGA sector RAM, and no basis for diagnosing SDRAM RTL from this one observation. Previous SDRAM pattern `00 39` remains a separate unclassified symptom.

## 13. Сектор 0 SD: прямое чтение 11 байт подтверждено аппаратно

Оператор после записи и проверки образа через Win32 Disk Imager прочитал с FPGA сектор 0 через прямое адресное окно SD-контроллера (банк `03`, page `00`, busy `00`). Результат:

```text
I007F,0001 -> 03
I0004,0001 -> 00
I0007,0001 -> 00
I0080,0001 -> 6E
I0081,0001 -> 61
I0082,0001 -> 6E
I0083,0001 -> 6F
I0084,0001 -> 00
I0085,0001 -> 00
I0086,0001 -> 00
I0087,0001 -> 01
I0088,0001 -> 0F
I0089,0001 -> E0
I008A,0001 -> F6
```

**Доказанный результат:** первые 11 байт физического сектора 0, доступные CPU Z80 из внутреннего буфера SD-контроллера, совпадают с исходным образом: `6E 61 6E 6F 00 00 00 01 0F E0 F6`. Это SD BOOT HEADER BOARD PASS (11 bytes), а **не** полный SD/image readback PASS, не OS LOAD PASS, не RAM PASS. Предыдущая последовательная команда `I000A,0010 -> 6E0000...` не исключает правильной работы оконного интерфейса `0x80-0xFF`, который использует загрузчик. Порт `0x0A` требует отдельного исследования.

**Следующий независимый тест SDRAM** — без запуска `L` или `J`, с ограниченными записями в несистемные области RAM:

```text
W4000,A5
W4001,5A
M4000,0002
WE000,3C
WE001,C3
ME000,0002
```

Ожидаем `4000: A5 5A` и `E000: 3C C3`. `E000` является целевым адресом загрузки CP/Mish; тестовые байты будут перезаписаны при последующей успешной `L`. Никаких выводов о неисправности SDRAM без результатов теста не делать.

## 14. CP/Mish BOOT PASS: A> appeared on physical HDMI (2026-11-11)

После повторной аппаратной загрузки nano-Z80 в FPGA SRAM и установки временных частот оператор выполнил `B` в ROM Monitor и подтвердил: **на HDMI появился приглашение `A>`**, MobaXterm на COM25 остался на введённой букве `B`. Это подтверждает **CP/Mish BOOT TO PROMPT BOARD PASS (HDMI CRT)** на Tang Nano 20K с microSD, но пока не подтверждает ввод команд или исполнение утилит `DIR`/`STAT`.

Это штатно: CP/Mish BIOS по умолчанию устанавливает IOBYTE `0x81`, выбирающий HDMI + USB keyboard (CRT), а не компьютерный UART. Переход ROM Monitor `B` к системе прекращает его ответы на COM25.

**Следующий шаг без повторной загрузки FPGA, PLL или SD:** нажать аппаратную S2 для возвращения в ROM Monitor; COM25 115200 8N1 → `Ready`; выполнить `L` (загрузить ОС, но не запускать), затем `MF633,0001` (ожидание `81`). Только при `81` выполнить `WF633,83`, `MF633,0001` (ожидание `83`) и `JF600`. Это выбирает консоль UC1 (USB UART Tang Nano 20K, COM25). Ожидание: приглашение `A>` в MobaXterm. Далее выполнить `DIR` для OS INTERACTIVE PASS. Если F633 не `81`, не выполнять запись/переход; считать это новой диагностикой.

Проверено по оригинальным `arch/nano-z80/README.md` и `bios.z80` проекта davidgiven/cpmish. В README есть опечатка `F833` в прозе, но точный пример `WF633,83` и смещение BIOS `0x33` от F600 дают `F633`.

## 15. UART CP/Mish BIOS banner PASS; CCP prompt NOT YET OBSERVED (2026-11-11)

После подтверждённой загрузки CP/Mish в HDMI CRT-режиме (`B` → `A>` на HDMI) оператор выполнил точную документированную процедуру переключения консоли на USB-UART COM25:

```text
Ready
MF633,0001
F633: 81
Ready
WF633,83
Ready
MF633,0001
F633: 83
Ready
JF600

CP/Mish 2.2r0 for nanoZ80
```

После строки приветствия `A>` на COM25 не появилось; оператор квалифицирует это как остановку до приглашения. **Вывод: BIOS BOOT BANNER UART PASS / CCP PROMPT UART NOT PASS.** Патч IOBYTE (0x81 → 0x83) доказан чтением RAM и выводом приветствия на UART. Не фиксировать CP/Mish INTERACTIVE PASS до ввода `DIR` в COM25.

По исходнику `arch/nano-z80/bios.z80`: `BOOTE` сначала отключает ROM, устанавливает `(IOBYTE)`, вызывает `TTYINIT` и печатает баннер; затем `call_ccp` устанавливает переходы 0000/0005 и делает `jp CBASE`. Следовательно, баннер не доказывает, что CCP дошёл до своего приглашения. Причина отсутствия `A>` пока НЕ установлена.

**Важная снятая гипотеза:** встроенный USB UART A использует небанковые порты `0x70–0x73` по `arch/nano-z80/include/nano-z80.lib`; переключение IO-bank на SD не объясняет зависание UART A само по себе (нельзя заявлять об ошибке UART A bank selection).

**Минимальная проверка без перезапуска/повторной прошивки**: один Enter в MobaXterm на COM25, наблюдать любой отклик; одновременно посмотреть, не выводится ли `A>` на HDMI. Если не реагирует и `A>` отсутствует на обоих выходах — только тогда исследовать первый переход CCP/BDOS, а не SD header, программирование FPGA или частоты MS5351.

## 16. Гипотеза перехода B vs L/J: неотключённый PIC IRQ

При запуске с SD штатной командой `B` ROM Monitor вывел `A>` на HDMI. После повторной загрузки через `L`, подтверждённого патча IOBYTE F633 (`81`→`83`) и `JF600` BIOS вывел `CP/Mish 2.2r0 for nanoZ80` в COM25, но CCP prompt `A>` не появился. Оператор уточнил: Enter в COM25 не обрабатывается; курсор HDMI находится в последней строке, мигает, приглашения `A>` нет.

**Существенное различие контрольных путей (прямо подтверждено исходниками):**

- `venomix666/nano-z80/romcode/nano-z80.z80`, `monitor_boot` (команда B): выполняет `di`, выбирает `IO_SELECT_PIC`, пишет `0x00` в `PIC_IRQ_ENABLE`, затем `sd_boot` и `jp (hl)`;
- `monitor_sd_load` (L): только `call sd_boot`, без отключения прерываний;
- `monitor_jump` (J): только `jp (hl)`, без отключения прерываний;
- `init_im2` в ROM Monitor включает PIC IRQ0 и таймер, использует IM2 векторную таблицу FE00; CP/Mish BIOS `BOOTE` выполняет `di`, отключает ROM и затем `ei` (davidgiven/cpmish/arch/nano-z80/bios.z80). Продолжение ROM-era IRQ после отключения ROM может привести к неверному обработчику. Это объяснение пока гипотеза, не аппаратно доказанный root cause.
- `venomix666/nano-z80/romcode/defines.z80`: `IO_SELECT_PIC=0x06`, `PIC_IRQ_ENABLE=0x00`; значит без перепрошивки можно точно воспроизвести действие `B` при ручном запуске.

**Следующий целевой аппаратный эксперимент (без дополнительного RAM/SD тестирования):** нажать S2 для ROM Monitor; дождаться `Ready`; выполнить последовательно:

```text
L
WF633,83
O007F,06
O0000,00
JF600
```

Последовательность `O007F,06; O0000,00` выбирает банк PIC и **запрещает** его IRQ. Это не строб SD-write и не изменение FPGA Flash/внешнего MS5351. В отличие от `B`, явного DI в ROM Monitor нет, но аппаратный IRQ от PIC будет заблокирован перед `JF600` (предполагая штатную работу PIC). Ожидание: баннер и `A>` через COM25; `DIR` подтверждает интерактивную работу. Если результата нет, не повторять SD диагностику; изучить CCP/BDOS entry and UART console.

**Вторая ранняя гипотеза об I/O-bank UART A снята**: он использует небанковые порты `70-73` (cpmish `nano-z80.lib`). Мигающий курсор на HDMI возможен из-за `TTYINIT`, вызываемого BIOS независимо от IOBYTE.

## 17. BOARD PASS: оператор подтвердил работу CP/Mish после отключения PIC IRQ

**2026-11-11.** В ответ на целевой эксперимент из раздела 16 (в ROM Monitor: `L`, `WF633,83`, `O007F,06`, `O0000,00`, `JF600`) оператор сообщил: **«Нет все работает. Вместе мы отличная команда...»**. Контекст: ранее тот же путь без `O007F,06; O0000,00` останавливался после `CP/Mish 2.2r0 for nanoZ80` без приглашения `A>` и без реакции на Enter. Значит, по сообщению оператора, ручная загрузка CP/Mish с UART-консолью теперь проходит успешно.

**Статус:** `CP/Mish UART STARTUP BOARD PASS — operator confirmed`; режим с активным ранее PIC IRQ останавливался после баннера, после явного сброса PIC IRQ enable — успешный запуск. Это сильное экспериментальное свидетельство участия прерываний в проблеме ручного перехода. **Точный механизм не доказан инструментально**; гипотеза о прерывании в период ROM disable остаётся гипотезой до трассировки. В этом сообщении оператор не предоставил отдельную текстовую квитанцию `DIR`, поэтому `DIR FILE LIST PASS` пока не фиксируем.

**Успешный ручной сценарий:** при сохранённом nano-Z80 FPGA SRAM и временных MS5351 тактах: S2 → `Ready` → `L` → `WF633,83` → `O007F,06` → `O0000,00` → `JF600`. На COM25 ожидается работающая CP/Mish. Никакие данные SD/Flash этими командами не перезаписываются.

**Следующие задачи отдельно от достигнутого PASS:** интерактивный `DIR` (при желании сохранить экран/лог), демонстрация CP/Mish программ, возможный BIOS/Monitor patch для UART boot без ручной PIC процедуры, затем FUZIX. Не смешивать с доказанным UART startup.

# PiKoSoL-20K / P20-SHELL-01 v0.2.0 — запуск с защищёнными ступенями

**Статус на 10.11.2026:** `HOST_TEST_PASS / RV32I_CROSS_BUILD_PASS / BOARD_NOT_TESTED`.

Сценарий рассчитан **только на уже работающий EX20-05.16** с LiteX BIOS `litex>`,
V201 `0x56323031` по `0xB1000000`, UART через COM25 и доступной SDRAM.
Он **не перепрошивает FPGA, не программирует Flash, не вызывает Gowin, не меняет HDL**.
Сам по себе `csr.csv` не доказывает, что подключённая плата настроена именно этой сборкой.
До любой операции оператор сверяет происхождение установленного образа EX20-05.16.

## Одна проверка на ПК

Нужен отдельный чистый worktree, без сброса/перезаписи локальных изменений 9K:

```powershell
git -C C:\GitHub\Sipeed-FPGA fetch origin feature/pikosol20k-vexriscv-shell-v0.1
git -C C:\GitHub\Sipeed-FPGA worktree add --detach C:\GitHub\Sipeed-FPGA-P20-SHELL-01 origin/feature/pikosol20k-vexriscv-shell-v0.1
Set-Location C:\GitHub\Sipeed-FPGA-P20-SHELL-01\Tang-Nano-20K\PiKoSoL-20K
```

Укажите **реальный файл** `csr.csv` от той EX20-05.16, которая была собрана оператором.
В GitHub нет доказанной копии `build/csr.csv` с локального ПК. Пример пути не заменяет проверки:

```powershell
$SocMap = 'C:\GitHub\Sipeed-FPGA\Tang-Nano-20K\Examples\EX20-05-CPU-HDMI\build\csr.csv'
python .\tools\soc_map_guard.py "$SocMap" --output .\build\evidence\soc_map_preflight.json
```

Требуется `MAP_STRUCTURE_PASS_NOT_BOARD_PASS`. Если не найден `uart`/`video`/`main_ram`,
адреса `uart_rxtx/txfull/rxempty` или объём SDRAM несовместимы — **STOP**.
Не подставлять заводскую карту адресов «по памяти».

```powershell
bash ./tools/test_host.sh
# BASE только из фактически проверенного stdout soc_map_guard.py.
bash ./tools/build_rv32.sh 0xF0003000
python ./tools/board_accept.py
```

`0xF0003000` в примере — значение из **LAB-20.6**, а не утверждение о EX20-05.16.
Если `soc_map_guard.py` вывел другой UART_BASE, пересобрать с тем, который он указал.
Ожидаемые файлы `build/pikosol20k.bin`, `build/pikosol20k.sha256` и
`build/pikosol20k_build.json`. Последний связывает хеш/байты бинарника
с **конкретным UART_BASE**. Даже при правильной сигнатуре V201 загрузка
будет остановлена, если программа скомпилирована под другую карту UART.
Не переносить бинарник с отличающейся картой/хешем.

## Ступень A: только BIOS/V201 чтения

Закройте MobaXterm и другие программы, занимающие COM25. Для live COM-команд
понадобится `python -m pip install pyserial` в активном Python.

```powershell
python ./tools/board_accept.py --probe --port COM25 --csr-csv "$SocMap" --receipt ./build/evidence/probe.json
```

Сценарий отправляет только пустую строку для синхронизации BIOS и чтения
`mem_read 0xB1000000 4`, `mem_read 0xB100001C 4`, `mem_read 0xB1000014 4`.
Требует ожидаемый ID и VERSION `0x00010000`, `BUSY=0`.
Никаких `mem_write` не выдаёт. Если нет ответов либо неверен ID — **STOP**.

## Ступень B: только SDRAM и обязательный readback

```powershell
python ./tools/board_accept.py --upload --port COM25 --csr-csv "$SocMap" --receipt ./build/evidence/upload.json
```

Порядок: хеш BIN ↔ SHA256-файл, проверка карты, контроль V201, затем запись
**только** `0x40010000` и следующих word-aligned адресов до начала стека
`0x4001C000`. По умолчанию после загрузки выполняется **полное чтение
каждого байта**, включая padding последнего слова. Любая ошибка — STOP,
`boot` не вызывается. При успехе квитанция `SDRAM_READBACK_PASS`,
а старый BIOS остаётся активным.

Для проверки ранее загруженного образа без новой записи:

```powershell
python ./tools/board_accept.py --verify-only --port COM25 --csr-csv "$SocMap" --receipt ./build/evidence/readback.json
```

**Заводской LAB-20.6** использовал ранее другой битстрим. Положительный опыт
загрузки в него не считается подтверждением нового EX20-05.16.

## Ступень C: запуск только по решению оператора

После **документированного** B-pass (или свежего независимого verify-only)
откройте MobaXterm COM25 115200 8N1 и вручную напишите:

```text
boot 0x40010000
```

Передача управления необратима до физического RESET. Вариант автоматического
перехода в приложение после повторной загрузки существует, но специально
требует два флага:

```powershell
python ./tools/board_accept.py --upload --boot --confirm-boot --port COM25 --csr-csv "$SocMap" --receipt ./build/evidence/uart_boot.json
```

Ожидаемые строки `PiKoSoL-20K shell v0.1`, `VIDEO ID=0x56323031 OK` и
`PiKoSoL20K>`. Квитанция `UART_SHELL_PROMPT_OBSERVED_NOT_HDMI_PASS` означает
лишь прочитанное UART-приглашение, не визуальный факт.

### Демонстрация (сам оператор наблюдает монитор)

```text
HELP
INFO
STATUS
GFX
MOVE L
COLOR U
OBJ B
MOVE I
SIZE +
BG 102040
TERM
LED ?
GFX
```

Необходимы реальные видео + UART артефакты: скрин/видео прямоугольника,
координаты после MOVE, цвет после COLOR/BG, отсутствие фигуры после TERM,
лог команд и SHA256 BIN. `TERM` **не рисует буквы** в данной FPGA.

## Ступень D: восстановление и статус

Нажать **физический RESET**, проверить возвращение `litex>` и идентифицировать
видеорегистры. Никаких обращений к Flash или JTAG из этого набора.
При отсутствии BIOS — остановиться и рассмотреть проверенную отдельно
SRAM-only процедуру EX20-05.16, не экспериментировать с адресами.

| Отметка | Когда можно ставить |
| --- | --- |
| `HOST_TEST_PASS` | тестирование C+Python на ПК |
| `MAP_STRUCTURE_PASS_NOT_BOARD_PASS` | файл `csr.csv` прошёл статическую проверку |
| `V201_PROBE_PASS` | настоящий ответ платы по UART |
| `SDRAM_READBACK_PASS` | реальная запись/чтение всех байт |
| `UART_SHELL_PROMPT_OBSERVED_NOT_HDMI_PASS` | живой UART после `boot` |
| `BOARD_SHELL_PASS` | дополнительная ручная проверка всех команд, HDMI и восстановление |
| `TERM_HDMI_PASS` | **запрещено** до нового RTL/Gowin/board цикла |

**Замечание:** скрипт строго ограничивает команды BIOS: read только V201
и выделенной области SDRAM, write только SDRAM-код до стека, boot только
`0x40010000`. Отдельное приложение может затем писать предусмотренные V201
регистры, но уже по своей проверенной функции и после команды пользователя.

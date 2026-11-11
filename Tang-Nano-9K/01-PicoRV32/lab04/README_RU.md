# NEW: LAB-04.3 PiKoSoL v0.1.7

See [README_v017_LAB043_RU.md](README_v017_LAB043_RU.md) for programmable rectangles, UART/HDMI ASCII pseudographics, MMIO ABI, validation gates and non-claims.

---

# PiKoSoL LAB-04 v0.1.6 — LED MMIO -> HDMI HUD (кандидат, 22.10.2026)

Исходная точка: v0.1.5 подтверждена на Tang Nano 9K: Gowin SRAM Program,
HDMI изображение, PicoRV32 UART баннер, команды `1`, `?`, физические LED.

**НОВАЯ v0.1.6 ПОКА НЕ ПРОШЛА Gowin PnR/STA И ПЛАТУ.**
Добавлены handshake CDC для шести LED MMIO бит (27 МГц -> 25,2 МГц) и
графическая нижняя панель 640x480: шесть прямоугольников LED1..LED6.
Физический HDMI PHY, PLL/CLKDIV, reset OSER10 v0.1.5, SDC, ROM и UART ABI
сохранены без изменений. Смотри подробную инструкцию `README_v016.md`.
После новых STA/HW проверок: `tools/test_lab04_v016_board.ps1 -PortName COM10`.

---

## Историческая документация ранних кандидатов (ниже)

# PiKoSoL LAB-04 v0.1.4 - CPU OSER10 asynchronous-reset timing candidate

**Status: not built, not STA-passed, not board-tested.** The independent CPU Gowin report
for v0.1.3 (2026-10-22 13:03:12) shows 6072 paths, 4250 endpoints, 3 reported setup-
violated endpoints / setup TNS -0.385 ns, and the following three negative RESET
recovery slacks at the falling FCLK edge of OSER10: -0.244/-0.074/-0.068 ns.
The ordinary listed setup data paths have positive margins. Recovery endpoints
are the same three serializers; their slacks sum to -0.386 ns (rounding).

This patch changes **only** the final release of the 126 MHz SERDES reset:
three positive-edge synchronizer stages remain, and a new negative-edge
registered release drives OSER10.RESET through the existing HDMI module.
The reset still asserts asynchronously upon reset_n low or PLL lock loss.
It does NOT apply false_path or weaken SDC; the three existing bounded CDC
constraints are retained. No changes to PicoRV32, firmware ROM, UART, pins,
Sipeed vendored HDL, LAB-03, Gowin CLI or flash configuration.

**Reason for the experiment:** the OSER10 fast-clock capture/recovery in the
Gowin report is at the falling fast-clock edge. Releasing directly from the
positive-edge FF provides only half an FCLK period (~3.968 ns); a falling-edge
last FF is expected to move the outgoing recovery check to a full period.
This is a design hypothesis. A real post-PnR Gowin run must verify new
R->F FF setup, F->F OSER10 recovery and removal, pulse width, all domain
clocks, CDC pin matches and full pinout. If violations persist, do not program.

Use installer Apply-LAB04-CPU-Serdes-Fix.ps1 from a new Downloads staging folder,
then run existing `test_lab04.ps1 -ModelOnly` and `build_lab04.ps1 -Mode CPU`.
The installer makes a backup in an ignored build/ folder and refuses source
hash mismatches. See root README_PATCH.md for exact commands.

---

# PiKoSoL LAB-04 v0.1.3 — коррекция селектора физических CDC-входов

**Состояние:** кандидат SDC-исправления после точного диагноза Gowin TA1124/TA2003 в v0.1.2. **Ни новая Gowin сборка, ни STA, ни HDMI на плате пока НЕ проверены.**

- v0.1.2 попыталась выбрать `mem_start_B1_*` и `mem_stop_B1_*` как регистры через `get_regs`.
- Реальный Gowin 1.9.9 Beta-4 ответил `TA1124: The Obj is empty by get_regs {u_hdmi/u_term/mem_start_B1_*}`; `TA2003` в SDC line 15.
- v0.1.1 STA называл первые физические входы `mem_start_B1_0_s8/DI[0]` и аналоги. В 22 наиболее медленных путях — по 11 бит start/stop.
- v0.1.3 **в двух строках SDC** заменяет адресацию `get_regs` приёмной ступени на `get_pins {u_hdmi/u_term/mem_start_B1_0_s*/DI*}` и аналог для stop. Первый путь сброса не изменён.
- `*.vg` Gowin защищён шифрованием `pragma protect`; он НЕ является доступным для текстового анализа netlist. Имена взяты из открытого STA v0.1.1, а не из текста VG.
- Применяются ограниченные `set_max_delay 12.000 ns`; ни глобальные false_path, ни clock_groups не вводятся.
- Статический тест использует 22 адреса из STA для проверки на предметное соответствие шаблонов (модель Python `fnmatch`). **Это не проверка синтаксиса Gowin и не STA PASS.**

**Что проверять после сборки:** в `gowin_cli.log` отсутствие TA1124/TA2003, все три `TC_MAX_DELAY Actived` в полном STA и видимость обеих масок входов, 27/126/25.2 MHz clocks, 0 нарушенных setup/hold endpoints, положительный recovery/removal, факт маршрутизации 22 CDC входных сигналов. Даже при успешном STA требуется аппаратный HDMI BOARD тест.

**Установка:** скачать ZIP, распаковать в *новый* каталог Downloads (не в репозиторий), выполнить `Apply-LAB04-CDC-Pin-Fix.ps1 -Repo 'C:\GitHub\Sipeed-FPGA'`. Установщик проверяет исходную v0.1.2, делает резервные копии, не трогает LAB-03 или заводской Flash. Если исходники локально изменены, откажется перезаписывать. После установки:

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
python .\01-PicoRV32\lab04\tools\verify_kit.py
python .\01-PicoRV32\lab04\tests\test_sta_cdc_contract.py
& .\01-PicoRV32\lab04\tools\build_lab04.ps1 -Mode Smoke
# После Gowin: проверить существование отчёта STA и передать его с логом.
```

**Важная оговорка по CDC:** корректное прохождение STA с заданным `set_max_delay` лишь проверяет ограниченный маршрутизированный путь. Оно не доказывает отсутствие метастабильности и не заменяет проверку архитектуры синхронизатора/Gray-последовательности.

---

# Sipeed FPGA · LAB-04 — PicoRV32 + HDMI + USB-UART + 6 LED

**Версия:** v0.1.2 · 22 октября 2026 г. · **Статус: v0.1.0 STA FAIL; v0.1.1 STA FAIL (6 setup endpoints); v0.1.2 CDC timing constraints CANDIDATE, not yet compiled or tested on board**.

**Факт v0.1.1 после полного Gowin PnR/STA (архив LAB04_STA_v011.zip):** 3891 пути, 2070 endpoints; 6 setup-violated, 0 hold-violated; WNS setup -3.465 ns, recovery +0.547 ns, removal +1.959 ns. Основные остаточные нарушения: `u_clock/sys_release_q_2_s1 -> u_hdmi/u_term/oresetn_q_0_s0` (синхронизация снятия сброса 27 -> 25.2 МГц), пять путей `mem_start_GR`/`mem_stop_GR` -> первый этап приемника кода Грея `*_B1` (27 -> 25.2 МГц). Все 3 clock-домена распознаны.

**Изменение v0.1.2:** в `constraints/lab04_video.sdc` добавлены ровно три `set_max_delay` с пределом 12 нс к *первым* ступеням штатных SVO-синхронизаторов; не отключаем глобально STA между тактами и не используем `false_path`. Ограничения не замена RTL-CDC-аудиту: источник использует Gray-кодированные указатели FIFO и многокаскадные получатели; требуется сверка отчета, что каждая SDC-строка действительно применена (TC_MAX_DELAY active), а setup/hold/recovery/removal и прочие пути не нарушены. Не объявлять v0.1.2 STA_PASS до реальной сборки. Новый `tools/check_sta_v012.py` — доп. автоматизированный gate по HTML; не заменяет инженера.


**STA v0.1.0 evidence:** из отчёта 22.10.2026: 4079 путей, 135 setup violated endpoints,
WNS setup -6.514 ns (27 -> 25.2 МГц, `release_sync` -> `svo_tcard`),
WNS recovery -1.036 ns (25.2 -> 126 МГц, `resetn_clk_pixel_q` -> `OSER10.RESET`),
0 hold violations. Файл `.fs` из v0.1.0 *не допущен* к программированию.

**Изменения v0.1.1:** отдельные трехкаскадные сбросы для 27, 25.2 и 126 МГц с
асинхронным утверждением и синхронным снятием; независимый `pixel_resetn`
для `svo_tcard`, `svo_overlay`, `svo_enc`; `serdes_resetn` для `OSER10.RESET`.
Сторонние модули Sipeed и временные ограничения SDC не изменены. Это
**кандидат на исправление**: `LAB04_STA_PASS` можно утверждать только по
новому PnR/STA, а `LAB04_HDMI_BOARD_PASS` только после физической проверки.

Это отдельный новый эксперимент для **Sipeed Tang Nano 9K / GW1NR-9C**. Он не требует пайки, дополнительных GPIO-адаптеров, PS/2-клавиатуры или внешнего USB-TTL: для клавиатуры используется **штатный USB-UART платы** и ПК; для изображения — **штатный HDMI-разъём**. HDMI формирует аппаратная видеологика FPGA, а не видеокарта ПК.

**Мы сделали две независимые конфигурации:**

1. **Smoke / LAB-04.1:** контроллер HDMI и цветовая тестовая таблица с текстом `LAB-04 HDMI TEST`. PicoRV32 в этой сборке **нет**. Встроенные LED циклически демонстрируют 0…6 включённых ламп. Цель — проверить физический видеотракт, Gowin IP и монитор без смешивания с процессорной логикой.
2. **CPU / LAB-04.2:** независимая SoC PicoRV32 RV32I с новой 235-инструкционной ROM, UART и шестью LED. Два пассивных декодера сериализованных линий RX/TX направляют введённые с ПК символы и сообщения процессора на видеотерминал SimpleVOut. CPU работает от платы 27 МГц, HDMI от PLL + CLKDIV (пара ~125.875/25.175 МГц по официальному PicoTiny). Видеокадр — 640×480 около 60 Гц, не заявлена поддержка аудио/HDCP/EDID.

**Почему именно такой путь:** имеется официальный [Sipeed PicoTiny](https://github.com/sipeed/TangNano-9K-example/tree/c3b795799f23de91982be52db4273a8eea100cdb/picotiny) с PicoRV32, текстовым HDMI-терминалом, TMDS и PLL, рассчитанный на Tang Nano 9K. Мы используем его **как фиксированную стороннюю зависимость**, не копируем/изменяем LAB-03. Сторонние исходники автоматически скачиваются **при явном запуске** `fetch_picotiny.ps1`, сохраняются с оригинальными лицензионными заголовками под уже игнорируемой Git папкой `01-PicoRV32/vendor/picotiny_ref/`.

## Правило доказательности

- **Подтверждено здесь:** детерминированная сборка ROM 235/256 слов; 7 тестов независимой Python ISA-модели и 6 статических проверок исходников/выводов (все значения `count 0..6`, шесть одиночных LED, `?`, ошибки, `CR/LF`); статические проверки исходников и Python-CLI.
- **Не подтверждено до запуска на Windows:** сборка Icarus TB пассивного UART-монитора, сам Gowin PnR/STA/Fmax/ресурсы, действительные видеотайминги и изображение через HDMI. Присваивать `LAB04_HDMI_BOARD_PASS` или `LAB04_CPU_HDMI_BOARD_PASS` заранее **запрещено**.
- **Только исходники с правильным pinout:** HDMI парные контакты и clock IP сверены с Sipeed PicoTiny, но конфликтов с конкретной ревизией платы или настройками Gowin нельзя полностью исключить без аппаратного прогона.
- **LAB-03 не изменяется:** другие RTL, ROM, трассы T3, Gowin проекты и ваши незакоммиченные файлы не заменяются. Не путайте LED-протокол LAB-04 с прежним LAB-03: цифра `4` в LAB-03 включала **только L4**; в новом LAB-04 цифра `4` включает **L1–L4**.

## Структура файлов — что для чего

| Файл | Назначение |
|---|---|
| `rtl/lab04_svo_hdmi_top.v` | Адаптация официального SVO HDMI top (с сохранением оригинального лицензионного уведомления): **отдельно выводит именно `term_in_tready`**, чтобы не путать его с `term_out_tready` видеоналожения и не терять символы. |
| `rtl/lab04_video_clocks.v` | PLL/CLKDIV для видеотаймингов, раздельный reset release для 27/25.2/126 МГц. |
| `rtl/lab04_hdmi_smoke_top.v` | **Первый тест HDMI без CPU**: testcard+баннер, демонстрация LED 0…6. |
| `rtl/lab04_cpu_soc.v` | Новая минимальная SoC (1KiB ROM, MMIO LED, UART RX/TX), отдельная от LAB-03. |
| `rtl/lab04_cpu_hdmi_top.v` | Верхний уровень CPU+HDMI+USB-UART+LED. |
| `rtl/lab04_uart_tty_bridge.v` | Пассивное декодирование входного и выходного UART + отдельные FIFO символов. |
| `rtl/lab04_boot_rom.v` | **Сгенерированная** Verilog ROM для LAB-04 (не менять вручную). |
| `firmware/lab04_boot.S` | Исходник RV32I-прошивки с простым макросом `.emit` для ASCII-текста. |
| `firmware/lab04_boot.hex` | Сгенерированные 256 машинных слов (235 инструкций + 21 NOP). |
| `firmware/lab04_rom_meta.json` | SHA-256 и параметры детерминированной ROM-сборки. |
| `tools/build_rom.py` | Сборщик ROM без внешних Python-пакетов; `--check` проверяет тождественность. |
| `tools/console_lab04.py` | Терминал клавиатуры ПК → встроенный UART. Нужен pyserial только для физического COM. |
| `tools/fetch_picotiny.ps1` | Однократная загрузка **пинованного** стороннего HDMI RTL / Gowin IP. |
| `tools/test_lab04.ps1` | Проверка прошивки и (если есть Icarus) UART-моста без программирования FPGA. |
| `tools/build_lab04.ps1` | Создаёт **отдельную копию проекта в `lab04/build/`** и вызывает Gowin CLI. Не меняет LAB-03. |
| `tools/program_lab04_sram.ps1` | Проверяет `.fs` и опционально программирует **только SRAM** при `-Program`. По умолчанию — dry run. |
| `tests/test_lab04_model.py` | ISA-уровневая модель и 7 тестов, без физической платы. |
| `tests/test_lab04_sources.py` | 6 проверок состава Gowin/TMDS исходников, штатных выводов платы и изоляции LAB-03. |
| `tests/tb_lab04_uart_tty_bridge.v` | Icarus RTL-тест двух независимых UART-декодеров. |
| `constraints/*.cst`, `constraints/lab04_video.sdc` | Штатные HDMI/GPIO/USB-UART выводы Tang Nano 9K и базовое ограничение 27MHz. |
| `build_scripts/*.tcl` | Независимые Gowin CLI сборки Smoke и CPU. |
| `tools/verify_kit.py`, `SHA256SUMS.txt` | Проверка полного комплекта после скачивания. |

## 1. Установка, безопасная для вашей текущей работы

**Локальный репозиторий:** `C:\GitHub\Sipeed-FPGA`.

Сначала проверьте, что папки LAB-04 ещё не существуют. Архив добавляет только **новые каталоги** `01-PicoRV32/lab04/` и `docs/lab04/`. Если там уже есть ваши файлы, не распаковывайте поверх них.

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
Test-Path .\01-PicoRV32\lab04
Test-Path .\docs\lab04
# Ожидается False, False
Expand-Archive "$HOME\Downloads\Sipeed_LAB04_PicoRV32_HDMI_v0.1.0.zip" -DestinationPath .
```

**Не используйте** `git clean -fd`, `git reset --hard`, `git add .` или автоматическую пересборку старой LAB-03: ваша рабочая копия содержит важные незакоммиченные изменения.

## 2. Всё, что можно проверить ещё без монитора

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
python .\01-PicoRV32\lab04\tools\verify_kit.py
python .\01-PicoRV32\lab04\tools\build_rom.py --check
python .\01-PicoRV32\lab04\tests\test_lab04_model.py
python .\01-PicoRV32\lab04\tests\test_lab04_sources.py
python .\01-PicoRV32\lab04\tools\console_lab04.py --dry-run
& .\01-PicoRV32\lab04\tools\test_lab04.ps1 -ModelOnly
```

Если имеется Icarus Verilog (`iverilog`, `vvp`) — тест UART-зеркала (два одновременных символа) без FPGA:

```powershell
& .\01-PicoRV32\lab04\tools\test_lab04.ps1
```

Ожидается `LAB04_UART_TTY_RTL_PASS`, но до фактического выполнения это **PENDING**.

## 3. Загрузка фиксированного Sipeed PicoTiny (нужен интернет один раз)

```powershell
& .\01-PicoRV32\lab04\tools\fetch_picotiny.ps1
```

Скачивается архив из [официального репозитория Sipeed](https://github.com/sipeed/TangNano-9K-example/tree/c3b795799f23de91982be52db4273a8eea100cdb/picotiny), ревизия `c3b795799f23de91982be52db4273a8eea100cdb`, извлекаются **только видеомодули и обёртки PLL/CLKDIV**. Уже существующий каталог стороннего кода не перезаписывается. При необходимости можно скачать архив вручную, затем вызвать `fetch_picotiny.ps1 -Archive "C:\path\to\vendor.zip"`.

CPU `vendor/picorv32/picorv32.v` был подготовлен в LAB-03. Если он отсутствует, используйте штатный `01-PicoRV32/tools/fetch_picorv32.ps1` и зафиксированный в проекте CPU commit `ef203c2b0a3fb793280f5114941416c425c5b461`.

## 4. Сборка Gowin в отдельном каталоге

Не требуется запускать GUI. Путь к установленной Gowin Education по умолчанию: `C:\Gowin\Gowin_V1.9.9Beta-4_Education`.

**Сначала HDMI без PicoRV32:**

```powershell
& .\01-PicoRV32\lab04\tools\build_lab04.ps1 -Mode Smoke
```

**После прохода Smoke — полный компьютер:**

```powershell
& .\01-PicoRV32\lab04\tools\build_lab04.ps1 -Mode CPU
```

В обоих случаях в игнорируемом каталоге `01-PicoRV32/lab04/build/<mode>_<timestamp>/` создаются **копии входных HDL и vendor IP**. Старые `01-PicoRV32/impl/`, `firmware/boot.hex`, `rtl/boot_rom.v`, LAB-03 `lab03_boot.hex` **не используются как выходы** и не изменяются. Внутри каталога сборки остаются логи и отчёты; после завершения ожидается уникальный `.fs` и его SHA-256. **Наличие `.fs` ещё не означает STA/BOARD PASS**; изучите отчёты Gowin.

Если сборка не проходит, сохраните `gowin_cli.log` и фактические файлы отчётов и остановитесь: никаких автоматических изменений тактов, IP и constraints.

## 5. Первый физический запуск, когда появится монитор

Нужен HDMI-кабель и монитор. Сначала подключить штатный HDMI платы. После проверки timing/ресурсов разрешить **только SRAM** (не Flash), например:

```powershell
$fs = 'C:\GitHub\Sipeed-FPGA\01-PicoRV32\lab04\build\<ваша_сборка>\lab04_hdmi_smoke_nano9k.fs'
& .\01-PicoRV32\lab04\tools\program_lab04_sram.ps1 -Bitstream $fs
# dry run: проверьте путь, SHA-256 и название операции.
& .\01-PicoRV32\lab04\tools\program_lab04_sram.ps1 -Bitstream $fs -Program
```

**Ожидаемая картинка Smoke** (до аппаратной проверки — только прогноз): тестовая таблица SVO с текстом `LAB-04 HDMI TEST` и `SVO`. Физические LEDs постепенно нарастают 0→6 и возвращаются к 0. Если изображения нет — зафиксируйте тип монитора и его сообщение об отсутствии сигнала, затем проверьте PLL/STA/HDMI constraints, не меняя старую LAB-03.

При удачном Smoke можно собрать и отдельно запрограммировать FPGA образ `picorv32_lab04_hdmi_nano9k.fs` из режима `CPU`.

## 6. Управление шестью светодиодами через ПК

В LAB-04 новый протокол специально разделяет два режима. **Цифра означает количество зажжённых LED**, а буква — отдельный LED. Каждый запрос PicoRV32 читает обратно MMIO перед отправкой подтверждения.

| Команда | На плату передаётся | Логическая маска | Ответ CPU |
|---|---|---:|---|
| `count 0` | ASCII `0` | `0x00` | `C=0` |
| `count 1` | ASCII `1` | `0x01` | `C=1` |
| `count 2` | ASCII `2` | `0x03` | `C=2` |
| `count 3` | ASCII `3` | `0x07` | `C=3` |
| `count 4` | ASCII `4` | `0x0F` | `C=4` |
| `count 5` | ASCII `5` | `0x1F` | `C=5` |
| `count 6` | ASCII `6` | `0x3F` | `C=6` |
| `one 4` | ASCII `d` | `0x08` | `L=4` |
| `mask` | ASCII `?` | Read-only | `M=XX` |

Используем встроенный USB-UART, например COM10 (фактический порт выбирается на ПК):

```powershell
python -m pip install pyserial
python .\01-PicoRV32\lab04\tools\console_lab04.py --port COM10
```

В окне терминала можно ввести `count 4`, `one 4`, `mask`, `demo`, `exit`. Команда `demo` выполняет 0→1→2→3→4→5→6→5→4→3→2→1→0. На HDMI показываются вводимые байты и ответы PicoRV32, на плате — соответствующая маска LED. **Это пока функциональное ТЗ/ROM-модель, не объявление физически испытанного результата.**

## 7. Что важно для дальнейшей разработки

- Текущий экран — **терминал поверх тестового фона SimpleVOut**, а не framebuffer 640×480 и не графическая ОС. Графический MMIO с линиями/прямоугольниками — отдельная следующая LAB-04.3 после успешного HDMI.
- HDMI TMDS реализуется штатными Gowin `OSER10` и `ELVDS_OBUF`, пригодность видеоконтроллера и PLL зависит от установленного Gowin и конкретной платы.
- Никакого видео потока по USB: ПК служит только клавиатурой и последовательной консолью.
- Программы LAB-03 и их аппаратные трассы не объявляются эквивалентными новому LAB-04: изменены прошивка и поведение UART `0..6`.
- Если HDMI-монитор пишет `No signal`, а LED последовательность работает, это ещё не доказывает неисправность CPU: Smoke не содержит CPU.
- Исходные сторонние файлы Sipeed/SimpleVOut загружаются с исходными лицензиями/копирайтами; они не являются работой автора LAB-04. В `lab04_svo_hdmi_top.v` сделана локальная документированная адаптация интерфейса ready/valid, её разрешительная лицензия сохранена.

**Граница выпуска v0.1.0:** подготовлен реальный исходный пакет и воспроизводимая модель; PnR/STA/физические испытания — следующий самостоятельный этап на вашем Windows-компьютере.


### LAB-04 CPU v0.1.5: experimental lane-local OSER10 reset

CPU v0.1.4 completed PnR but STA failed: 3 setup-violated endpoints,
setup TNS -0.453 ns, and worst recovery slack -1.498 ns. The negative-edge
SERDES reset-release FF introduced a new failing 126 MHz falling ->
25.2 MHz rising recovery relation. The routed data delay of the reset net
was ~4 ns and its route component ~3.58 ns.

v0.1.5 removes that negative-edge release and instead introduces three
individual 126 MHz rising-edge registers in the HDMI wrapper. All three
registers async-assert on falling serdes_resetn and sync-release with the
126 MHz clock; each directly drives one OSER10 RESET. Their preservation
is requested with Gowin syn_preserve. This may reduce reset-routing delay
by allowing placement close to each output serializer. Third-party video
cores, CPU firmware, UART, SDC and pin locations remain unchanged.

**This patch is an unverified timing-closure candidate, NOT a STA or BOARD PASS.**
Gowin must demonstrate that all three lane FFs survive synthesis,
are physically located near OSER10, and yield nonnegative setup/hold,
recovery and removal slack. Reject the bitstream otherwise. Smoke v0.1.3
board-proven image is unchanged and remains separately recoverable.

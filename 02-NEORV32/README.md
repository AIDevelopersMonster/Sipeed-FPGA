# LAB-06 / NEORV32 — Tang Nano 9K

**Единая точка продолжения / CANONICAL NEXT-SESSION HANDOFF**  
**Статус на 26.10.2026: LAB-06.1A TOOLCHAIN READY (operator); LAB-06.1B исходники подготовлены, SIM/FIT/STA/BOARD NOT RUN.**

> **Начинаем с минимального NEORV32 и прошитой в IMEM программы; не с SD, HDMI, Zephyr и не с копирования чужой конфигурации User Flash.** Цель — получить реальный `NEORV32 READY` по UART и управление шестью LED на Sipeed Tang Nano 9K, после чего провести честное сравнение с PicoRV32.

Это **главный README для следующего диалога**. При завершении каждого подтверждённого этапа обновляйте таблицу статусов ниже, имя прошивки, SHA-256, дату и точную следующую команду. Нельзя объявлять шаг выполненным только потому, что создан RTL или README.

## Контрольная точка 26.10.2026, 13:07 — TOOLCHAIN READY; LAB-06.1B source candidate

**Оператор подтвердил: LAB06_UCRT64_TOOLCHAIN_READY + LAB06_SOURCE_PREFLIGHT_PASS.** GHDL 6.0.0, RISC-V GCC 16.1.0, GNU Make, host GCC, Icarus и Gowin CLI доступны на Windows. MSYS2 завершил обновление; конфликт gcc-libs устранён. Исходники CPU неизменно pinned: `b2620454ebb2407e81a6a1965ef52e2a860b0432`.

**ПОДГОТОВЛЕНО НА GITHUB:** настоящий NEORV32 VHDL wrapper (`BOOT_MODE_SELECT=2`, ROM 16 KiB, RAM 2 KiB, встроенный UART, 6 GPIO), минимальная freestanding RV32I программа, линкер, GHDL VHDL тестбенч (физический UART 8N1 + GPIO), PowerShell-скрипт с изолированным каталогом сборки. Все исходники под `02-NEORV32/{firmware,rtl,tests,tools,constraints}`, применимы только с закреплённым upstream.

**ПРОГРАММА И СИМУЛЯЦИЯ ЕЩЁ НЕ ЗАПУЩЕНЫ НА WINDOWS**. Синтез, STA, FPGA и SD также NOT RUN; не объявлять PASS на основании коммита. Использование оригинального upstream `imem_image` вместо собранного образа запрещено; `run_lab061.ps1` подменяет его в отдельной GHDL file-list, не изменяя `_deps/neorv32`.

### Точная следующая команда — LAB-06.1B SIM

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin
git restore --source origin/main --worktree -- `
  02-NEORV32/README.md `
  02-NEORV32/.gitignore `
  02-NEORV32/firmware `
  02-NEORV32/rtl `
  02-NEORV32/tests `
  02-NEORV32/constraints `
  02-NEORV32/tools/run_lab061.ps1

.\02-NEORV32\tools\activate_ucrt64.ps1
.\02-NEORV32\tools\run_lab061.ps1 -Mode Sim
```

Ожидаемая **цель**, пока НЕ достигнутый результат: `LAB061_FIRMWARE_IMAGE_BUILT`, `LAB061_GHDL_ELAB_OK`, `LAB061_NEORV32_UART_GPIO_TB_PASS`, `LAB061_SIM_PASS`. Скрипт сохраняет `_build/run_*/{build.log,ghdl_import.log,ghdl_make.log,ghdl_sim.log,receipt.json}` и SHA256. **При ошибке не переписывать автоматически CPU:** смотреть конкретный tail лога, входные адреса памяти и UART.

Прежде чем переходить к Gowin, необходимо реальное `SIM PASS` на операторском Windows. **Это первая из двух-трёх ограниченных проверок до платы; Flash не затрагивается.** После SIM PASS обновить этот README с точными логами, затем готовить Gowin FIT/STA.

## Контрольная точка 26.10.2026, 12:50 — MSYS2 toolchain blocked (NO PACKAGES CHANGED)

**Source: PASS. Toolchain: BLOCKED (dependency resolution). SIM/FIT/STA/BOARD: NOT RUN.**

Operator executed `pacman -Syu` and confirmed MSYS2 core update that closed MSYS2 processes, but **did not run the second `pacman -Syu` required to complete the full system upgrade**. An immediate `pacman -S --needed ... ghdl-mcode ... gcc ... make` produced an old/new GCC library conflict:

- Existing `mingw-w64-ucrt-x86_64-gcc-libs 16.2.0-3` provided the *virtual* `mingw-w64-ucrt-x86_64-cc-libs`.
- New `mingw-w64-ucrt-x86_64-libgcc 16.2.0-6` conflicts with that old `gcc-libs`.
- Fresh packages `mingw-w64-ucrt-x86_64-cc-libs 16.2.0-6` and `gcc-libs 16.2.0-6` must be handled **in the full system upgrade**. The first attempted install failed at `failed to prepare transaction (could not satisfy dependencies)`; **do not claim any packages removed/installed**.

**Next safe action: complete the official MSYS2 full upgrade before installing additional packages**. Do NOT run `pacman -Rdd`, `--nodeps`, delete DLLs or reinstall MSYS2. PowerShell commands:

```powershell
$Pac = "C:\msys64\usr\bin\pacman.exe"
& $Pac -Syu
if ($LASTEXITCODE -ne 0) { throw "Full MSYS2 upgrade failed: inspect output before further changes" }
```

If MSYS2 closes processes once more, repeat `& $Pac -Syu` from a fresh console. The successful output should end with `there is nothing to do` on the subsequent full-upgrade check. Then install:

```powershell
& $Pac -S --needed `
    mingw-w64-ucrt-x86_64-ghdl-mcode `
    mingw-w64-ucrt-x86_64-riscv64-unknown-elf-gcc `
    mingw-w64-ucrt-x86_64-gcc `
    make
if ($LASTEXITCODE -ne 0) { throw "Toolchain package install failed" }
Set-Location C:\GitHub\Sipeed-FPGA
.\02-NEORV32\tools\activate_ucrt64.ps1
.\02-NEORV32\tools\preflight.ps1
```

If a dependency conflict recurs **during the full `-Syu`**, do not approve arbitrary removals: capture full output and these nonmutating diagnostics:

```powershell
& $Pac -Q mingw-w64-ucrt-x86_64-gcc-libs
& $Pac -Si mingw-w64-ucrt-x86_64-gcc-libs
& $Pac -Si mingw-w64-ucrt-x86_64-cc-libs
& $Pac -Si mingw-w64-ucrt-x86_64-libgcc
```

Package verification: [MSYS2 update procedure](https://www.msys2.org/docs/updating/), [new gcc-libs](https://packages.msys2.org/packages/mingw-w64-ucrt-x86_64-gcc-libs), [new cc-libs](https://packages.msys2.org/packages/mingw-w64-ucrt-x86_64-cc-libs), [new libgcc](https://packages.msys2.org/packages/mingw-w64-ucrt-x86_64-libgcc). **No FPGA programming or CPU simulation attempted.**

## Контрольная точка 26.10.2026 — SOURCE PIN PASS (оператор)

**LAB-06.1A SOURCE PASS подтверждён дважды на Windows. NEORV32 SIM / Gowin FIT / STA / BOARD пока NOT RUN.**

- Закреплённый исходный commit: `b2620454ebb2407e81a6a1965ef52e2a860b0432`; проверка `LAB06_SOURCE_PIN_PASS`.
- BSD-3-Clause: `LAB06_UPSTREAM_LICENSE_PASS`; BOOT_MODE_SELECT=2 и IMEM/DMEM/UART/GPIO generics: `LAB06_BOOT_INTERFACE_PASS`.
- Gowin CLI и Programmer обнаружены: `C:\Gowin\Gowin_V1.9.9Beta-4_Education`.
- Первый preflight: `02-NEORV32/_reports/LAB06_PREFLIGHT_20261026_123200.json`; второй: `LAB06_PREFLIGHT_20261026_123231.json`; третий после активации MSYS2: `LAB06_PREFLIGHT_20261026_124228.json`. Квитанции остаются локальными, не в Git.
- После запуска `activate_ucrt64.ps1` подтвердилось: **MSYS2 `C:\msys64` доступен**; `iverilog.exe` и `vvp.exe` уже установлены в `C:\msys64\ucrt64\bin`, а Python найден там же. **Отсутствуют** `ghdl`, `riscv64-unknown-elf-gcc`, `make`, host `gcc`. Проверка инструментов: `LAB06_UCRT64_TOOLCHAIN_INCOMPLETE`. **Icarus устанавливать повторно нельзя/не нужно.**

### Новая ближайшая команда (после третьего preflight в 12:42)

Пакеты подтверждены по официальному каталогу MSYS2; используем **GNU Make из MSYS** (его исполняемый файл называется `make.exe`, а UCRT64-пакет предоставляет `mingw32-make.exe`, не эквивалентное имя). **Сначала завершить полный system upgrade**, затем отдельно устанавливать пакеты:

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
$Pac = 'C:\msys64\usr\bin\pacman.exe'
& $Pac -Syu
if ($LASTEXITCODE -ne 0) { throw 'MSYS2 full update failed; do not install packages yet' }
```

Если MSYS2 обновляет core и просит закрыть процессы, выполнить требование, открыть новый PowerShell и **ещё раз** `& 'C:\msys64\usr\bin\pacman.exe' -Syu` до полного завершения обновления. Только затем:

```powershell
$Pac = 'C:\msys64\usr\bin\pacman.exe'
& $Pac -S --needed `
    mingw-w64-ucrt-x86_64-ghdl-mcode `
    mingw-w64-ucrt-x86_64-riscv64-unknown-elf-gcc `
    mingw-w64-ucrt-x86_64-gcc `
    make
if ($LASTEXITCODE -ne 0) { throw 'MSYS2 package installation failed' }
.\02-NEORV32\tools\activate_ucrt64.ps1
.\02-NEORV32\tools\preflight.ps1
ghdl --version
riscv64-unknown-elf-gcc --version
make --version
gcc --version
```

Следующий требуемый результат: `LAB06_UCRT64_TOOLCHAIN_READY` плюс `LAB06_SOURCE_PIN_PASS`. **Это ещё не результат симуляции.** Источники больше не клонировать. После этого создать минимальную VHDL-обвязку и образ IMEM в отдельном каталоге; только затем GHDL SIM.
### Архив предыдущего шага: активация MSYS2 уже выполнена

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin
git restore --source origin/main --worktree -- 02-NEORV32/README.md 02-NEORV32/tools/activate_ucrt64.ps1
.\02-NEORV32\tools\activate_ucrt64.ps1
.\02-NEORV32\tools\preflight.ps1
```

`activate_ucrt64.ps1` только добавляет существующие папки MSYS2 UCRT64 к PATH **текущего процесса** и показывает четыре необходимые команды: `ghdl`, `riscv64-unknown-elf-gcc`, `make` и `gcc`. Ничего не устанавливает и не программирует.

При действительном отсутствии программ (путь MSYS2 по умолчанию `C:\msys64`), после полного обновления MSYS2:

```powershell
$Pac = 'C:\msys64\usr\bin\pacman.exe'
& $Pac -Syu
# Если MSYS2 потребует перезапустить все его терминалы, закончить обновление после перезапуска.
& $Pac -S --needed mingw-w64-ucrt-x86_64-ghdl-mcode mingw-w64-ucrt-x86_64-riscv64-unknown-elf-gcc mingw-w64-ucrt-x86_64-gcc make
.\02-NEORV32\tools\activate_ucrt64.ps1
.\02-NEORV32\tools\preflight.ps1
```

Пакеты доступны в [MSYS2 GHDL-mcode](https://packages.msys2.org/packages/mingw-w64-ucrt-x86_64-ghdl-mcode), [RISC-V GCC](https://packages.msys2.org/packages/mingw-w64-ucrt-x86_64-riscv64-unknown-elf-gcc), [MSYS2 make](https://packages.msys2.org/packages/make). Для `riscv64-unknown-elf-gcc` используйте `-march=rv32i -mabi=ilp32`. Важное правило MSYS2: сначала полное `pacman -Syu`, не частичное обновление только баз пакетов.

**Только после TOOLCHAIN READY:** создать отдельную minimal VHDL-обвязку NEORV32, сделать программу `NEORV32 READY` и GPIO6, сформировать IMEM image в изолированном build-tree, запустить GHDL SIM. `make image install` upstream меняет `rtl/core/neorv32_imem_image.vhd`: не модифицировать закреплённый upstream checkout без изолированной копии. Затем Gowin PnR/STA и до трёх испытаний FPGA, SRAM-only.

**Handoff для нового диалога:** источник уже скачан и проверен; не запускайте `-FetchUpstream` повторно. Начать с `activate_ucrt64.ps1`, затем GHDL/GCC/Make, а не с другой архитектуры CPU.

## 0. Следующий диалог: что читать и делать

**Repository:** https://github.com/AIDevelopersMonster/Sipeed-FPGA  
**THIS README:** https://github.com/AIDevelopersMonster/Sipeed-FPGA/blob/main/02-NEORV32/README.md  
**Local Windows repository:** `C:\GitHub\Sipeed-FPGA`. PowerShell 7, Gowin CLI, Icarus/другие инструменты по фактической доступности.

Начинать с:

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git status -sb
git fetch origin
# Если нет локальных незакоммиченных изменений, мешающих обновлению:
git pull --ff-only origin main

# Подтянуть точно закреплённые исходники NEORV32 в игнорируемую _deps/.
# Скрипт НЕ собирает и НЕ программирует FPGA:
.\02-NEORV32\tools\preflight.ps1 -FetchUpstream
```

**Контрольный результат SOURCE PIN PASS уже получен трижды.** Не просите повторять clone. Сначала GHDL, RISC-V GCC, Make и host GCC по разделу «Новая ближайшая команда», затем первый реальный VHDL SIM. **Следующий инженерный шаг после него:** независимый VHDL-wrapper + образ IMEM, симуляция, затем только Gowin PnR/STA. Не запускать программатор до прохождения этих этапов.

### Прямой промпт для нового диалога

> Продолжи LAB-06 из `Sipeed-FPGA/02-NEORV32/README.md` на текущем `main`. Это единственный источник статуса и следующего шага; прочитай также `docs/cpu-comparison/README.md`, `TYPICAL_BLOCKS.md` и `BENCHMARK_PROTOCOL.md`. Используй существующие локальные `C:\GitHub\Sipeed-FPGA` и инструменты PowerShell 7. Наша первая задача — NEORV32 `BOOT_MODE_SELECT=2`, 27 MHz, IMEM ROM + DMEM, UART 115200, 6 LED, без внешней Flash. Сначала оцени пригодность закреплённой upstream версии, проверь preflight и инструменты, затем предложи минимальные тестируемые файлы для симуляции и Gowin. Не изменяй PiKoSoL/Pong/SD и не объявляй SIM, FIT, STA или BOARD PASS без фактических логов. Проводи 2–3 аппаратных испытания максимум и сохраняй SHA-256. После очередного этапа обнови этот README для следующего диалога.

## 1. Выбранная техническая стартовая конфигурация

| Параметр | LAB-06.1A — первое исполнение | Обоснование |
| --- | --- | --- |
| FPGA | `Sipeed Tang Nano 9K / GW1NR-9C` | Тот же стенд, что PicoRV32 |
| Входной CLK | `27 MHz`; фиксировать действительную частоту в отчёте | Сравнимая исходная частота |
| CPU | **NEORV32** из закреплённого исходного commit (ниже) | Не подменять другим релизом |
| Язык RTL | **Исходный VHDL** (`neorv32` library) | Gowin поддерживает VHDL; GHDL — для независимой симуляции |
| Первая загрузка CPU | **Direct boot: `BOOT_MODE_SELECT=2`**, программа предзаписана в `IMEM` | Никакого UART bootloader и User Flash на первом шаге |
| ISA baseline | RV32I; `RISCV_ISA_M=false`, `RISCV_ISA_C=false`, другие факультативные расширения отключены, если не требуются самим CPU | Контролируемая база для сравнения; CSR/привилегированные механизмы NEORV32 отдельно учесть |
| ROM | `IMEM_EN=true`, целевой размер **16 KiB**, `IMEM` как ROM | Образ формируется до синтеза |
| RAM | `DMEM_EN=true`, **2 KiB** — целевая пробная конфигурация | Если 2 KiB не поддерживаются текущим linker/runtime, зафиксировать и выполнить отдельно нормализованный тест; не выдавать разные размеры за одинаковые |
| UART | Встроенный `IO_UART0_EN=true`, `115200 8N1` | Текст `NEORV32 READY` и затем обмен байтами |
| GPIO | `IO_GPIO_NUM=6`, инверсия для активного нуля на физических LED | Перемещение маски по 6 светодиодам |
| Optional | Debug/OCD off; XBUS off; SPI/SD/HDMI/Zephyr off; дополнительные таймеры только если минимально требуются runtime | Меньше риска и расход ресурсов |
| FPGA programming | **Только volatile SRAM**, существующий локальный Gowin Programmer | Не писать конфигурационную Flash и User Flash |
| Идентичность | SHA-256 upstream source + ROM image + input manifest + resulting `.fs` | Проверяемое аппаратное испытание |

**Выбор обоснован upstream:** в закреплённом `stnolting/neorv32` существует `rtl/test_setups/neorv32_test_setup_approm.vhd` с `BOOT_MODE_SELECT=2`, `IMEM_EN`, `DMEM_EN`; это ближайший безопасный шаблон. Мы создаём **свой** компактный wrapper с UART и шестью GPIO. Не копировать чужой полный Tang Nano 9K проект: его User Flash, внешняя память, Zephyr и интерфейсы более ранней версии CPU не относятся к этому испытанию. В частности, старые generics `MEM_INT_IMEM_EN/MEM_INT_DMEM_EN` не являются действующими именами в нашем pinned upstream; актуальные — `IMEM_EN/DMEM_EN`.

**Проверенные board-pin ориентиры** из существующего PiKoSoL: `clk=52`, `reset_n=3`, `LED pins=10,11,13,14,15,16` (active low), `UART TX=17`, `UART RX=18`. Использовать `boards/tang-nano-9k/experiments/sd07-pikosol-mmio/constraints/sd07_cpu_hdmi_sd.cst` как **источник для проверки**, но не переносить HDMI/SD constraints в новый маленький SoC. Точные физические подключения и I/O voltages проверить перед PnR.

**Замечание по Clock/Reset:** даже если upstream VHDL компилируется, потребуются работающий reset, корректное направление UART на FT2232 B и точное соответствие частоты `CLOCK_FREQUENCY=27000000`. Успешная симуляция не доказывает это.

## 2. Upstream, воспроизводимость, лицензия

- **Пин NEORV32:** https://github.com/stnolting/neorv32/tree/b2620454ebb2407e81a6a1965ef52e2a860b0432
- Commit: `b2620454ebb2407e81a6a1965ef52e2a860b0432`; запись в [`sources.lock.json`](../sources.lock.json) `stage02_cpu`.
- **Лицензия этого исходного commit: BSD-3-Clause**, проверена по `LICENSE` upstream; при копировании файлов сохранять заголовки и уведомления, не переносить весь vendor-каталог без необходимости.
- Рабочая VHDL библиотека upstream называется `neorv32`, список исходников и порядок — `rtl/file_list_core.f`; GHDL-пример `sim/`, VHDL→Verilog fallback `rtl/verilog/`.
- Образ прямой загрузки связан с `rtl/core/neorv32_imem_image.vhd`. Перед генерацией приложения проверить pipeline компиляции upstream `sw/example` и `sw/image_gen`, linker script и `BOOT_MODE_SELECT=2`.
- Пример платы [`jimmyw/tang_nano_9k_neorv32`](https://github.com/jimmyw/tang_nano_9k_neorv32) — **архитектурная справка**, НЕ безопасная прошивка для нашей задачи: там `UFLASH`, отдельная прошивка памяти, и иные CPU generics.
- **Нельзя включать `--user-flash`, `-f`, erase, SPI Flash или прошивку заводской конфигурации** ради простого сообщения UART.

`.\02-NEORV32\tools\preflight.ps1 -FetchUpstream` проверяет source SHA, BSD-3-Clause, список необходимых файлов и наличие инструментов, но **не исполняет** VHDL/CPU и не подключается к FPGA.

## 3. Минимальная последовательность проверок и критерии STOP

| Gate | Что делаем | Что считать PASS | Состояние |
| --- | --- | --- | --- |
| **06.1A SOURCE** | Закреплённая VHDL версия, лицензия, инструменты, простая конфигурация | `LAB06_SOURCE_PIN_PASS`, список tool versions, осмысленный выбор компиляции | **SOURCE PIN PASS (operator); tools pending** |
| **06.1B SIM** | Образ `NEORV32 READY` + GPIO test, VHDL wrapper + bench, GHDL/управляемая симуляция | CPU **действительно выполняет инструкции**, UART выдаёт ожидаемые байты, GPIO меняется; в тестбенче есть FAIL-сценарии | **NOT RUN** |
| **06.1C FIT/STA** | Gowin на GW1NR-9C, 27 MHz, pinout, ресурсы, CDC и все Slack | PnR завершён, ресурсный FIT, 0 нарушений setup/hold, положительные setup/hold/recovery/removal, никаких критических unconstrained paths | **NOT RUN** |
| **06.1D BOARD** | Волатильная загрузка `.fs`, COM/LED, протокол | **2–3** испытания: (1) UART идентификатор, (2) GPIO LED, (3) короткая RX/TX проверка при наличии | **NOT RUN** |
| **06.2 COMPARE** | Отдельный **минимальный** PicoRV32 с той же ISA/ресурсными условиями | Два паспортированных CPU/SoC и таблица объективных ресурсов/циклов | **NOT RUN** |

**Срок bring-up: 1–2 дня на плату.** Если 2–3 разумных теста не работают, **останавливаемся**: смотреть pinout, USB/JTAG, питание, 27 MHz, reset, UART COM и STA. Не делать пятнадцать бессистемных прошивок и не ремонтировать плату ради теста.

Если NEORV32 **не помещается** на 9K в точно выбранной конфигурации, сохраняем Gowin report и `NO_FIT`; не уменьшаем память/ISA незаметно и не выдаём другой вариант за сравнимый.

## 4. Одинаковые тесты для PicoRV32 / NEORV32

После первого BOARD PASS выполняем программу [сравнительного анализа](../docs/cpu-comparison/README.md):

- **CPU-only:** RV32I и одинаковые алгоритмы ALU/сдвигов, `S/B/J` декодирования, загрузки/сохранения и ветвлений; отсчёт cycles при установленном режиме и таймингах памяти.
- **Minimal SoC:** 27 MHz, сопоставимые IMEM/DMEM, UART 115200, шесть GPIO; отдельно фиксируем стоимость wrapper, памяти и native периферии.
- **Common-IP:** одинаковые RTL GPIO6, UART8N1, TIMER32 через два CPU bus adapters. Только после успешного baseline — SPI и SD CMD17 **read-only**.
- **Внутренние блоки:** независимые учебные ALU32, регистровый файл 32×32, RV32I Decoder; одинаковые test vectors, измерения LUT/FF/BRAM/частоты, без присвоения стороннего VHDL.

[Типовые блоки](../docs/cpu-comparison/TYPICAL_BLOCKS.md) · [Протокол измерений](../docs/cpu-comparison/BENCHMARK_PROTOCOL.md) · [Таблицы результатов](../docs/cpu-comparison/RESULTS_TEMPLATE.md).

**Никаких выводов о том, какой CPU быстрее/лучше, до измерений.** Существующий PiKoSoL PicoRV32+HDMI нельзя сравнивать напрямую с minimal NEORV32.

## 5. Не делать / Protected results

- Не переписывать работавшие PiKoSoL `v0.2.0`, HDMI, Pong/Breakout, опубликованные `.fs`, SD-06 CMD24 scratch и SD-08 FAT32 read-only.
- Игры ведутся отдельно в проекте **KonSol RetroStation**; LAB-06 — только CPU/SoC и типовые блоки в `Sipeed-FPGA`.
- SD-06 уже доказал **односекторную** запись с PC через UART и обратное восстановление, но **не** FAT32 file write; SD-07 CPU+HDMI+SD MMIO пока FIT-ONLY кандидат. Запись SD внутри CPU **не** является задачей LAB-06.1.
- Не начинать LiteX/VexRiscv, Rocket, ОС или полноценную файловую систему до независимого минимального NEORV32.
- Репозиторий `main` не должен получать неподтверждённые benchmark-PASS, бинарники с неизвестным SHA или чужой vendor-code без notices.

## 6. Состояние и следующий конкретный шаг / State ledger

**Последний документированный шаг (26.10.2026, 12:42):** preflight SOURCE PIN PASS после успешной активации MSYS2 UCRT64. Icarus Verilog/VVP, Python и Gowin CLI найдены; GHDL, RISC-V GCC, Make, host GCC отсутствуют. Никакой симуляции, FIT, STA или программирования FPGA не выполнялось.

**NOW / NEXT:** выполнить полный `pacman -Syu` (при необходимости повторить после перезапуска), установить четыре указанных пакета `-S --needed`, затем `.\02-NEORV32\tools\activate_ucrt64.ps1` и `.\02-NEORV32\tools\preflight.ps1` без `-FetchUpstream`. Затем в отдельном изолированном каталоге `02-NEORV32/rtl/` создать минимальную VHDL обвязку и тестовую программу `NEORV32 READY`, аккуратно связать `IMEM image` с полученным ПО, собрать реальную симуляцию.

**После каждого этапа:** заменить `NOT RUN` на фактические результаты с датой, commit, версией Gowin, input SHA, .fs SHA, STA отчётом, тестовым UART логом. Отдельные отчёты в `02-NEORV32/acceptance/`; большие локальные отчёты в игнорируемой `02-NEORV32/_reports/`.

## English: handoff summary

LAB-06 is starting with a **pinned upstream VHDL NEORV32** on Tang Nano 9K, 27 MHz, **direct boot from an initialized on-chip IMEM image** (BOOT_MODE_SELECT=2). Enable minimal UART0 and six GPIO outputs, with optional processor features, external Flash, HDMI, SD and Zephyr disabled. Start with the supplied read-only preflight, then **simulation → Gowin PnR/STA → no more than three board checks**. No NEORV32 SIM/FIT/BOARD result exists yet. Later compare **matched PicoRV32 vs NEORV32 CPU-only, native-SoC and shared-IP** configurations, including independent ALU/register-file/decoder and standard GPIO/UART/timer/SPI block tests. Update this README as the canonical next-session checkpoint.

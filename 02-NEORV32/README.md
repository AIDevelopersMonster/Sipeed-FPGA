# LAB-06 / NEORV32 — Tang Nano 9K

**Единая точка продолжения / CANONICAL NEXT-SESSION HANDOFF**  
**Статус на 26.10.2026: LAB-06.1B SIM PASS; LAB-06.1C новый PnR/STA PRELIM PASS после исправления CST, однако BankVccio нового FIT пока НЕ проверен. BOARD NOT RUN; SRAM не программировать до окончательного read-only аудита.**

> **Начинаем с минимального NEORV32 и прошитой в IMEM программы; не с SD, HDMI, Zephyr и не с копирования чужой конфигурации User Flash.** Цель — получить реальный `NEORV32 READY` по UART и управление шестью LED на Sipeed Tang Nano 9K, после чего провести честное сравнение с PicoRV32.

Это **главный README для следующего диалога**. При завершении каждого подтверждённого этапа обновляйте таблицу статусов ниже, имя прошивки, SHA-256, дату и точную следующую команду. Нельзя объявлять шаг выполненным только потому, что создан RTL или README.

## Контрольная точка — 26.10.2026, 14:46: NEW FIT PASS after clock-bank CST fix, BankVccio audit NEXT

**Подтверждено оператором по консольному логу на Windows:** повторная сборка Gowin с `BANK_VCCIO=3.3` в `constraints/lab061_nano9k.cst` успешно прошла синтез и PnR, создала новый битстрим, preliminary STA screen PASS. Нет данных об итоговом BankVccio в PnR-отчёте этой новой сборки. **Нет board pass, SRAM ещё не программировали.**

- Job: `02-NEORV32/_build/fit_20261026_144630_744_c86f33`.
- Exact candidate: `02-NEORV32/_build/fit_20261026_144630_744_c86f33/lab061_neorv32_nano9k.fs`.
- Candidate SHA256: `3E1DC3EB6DC464E3992C733078A564680D5F279E4D89BAA8A47CB9002246FC5F`. This supersedes `6BD42615371AFA901C21DADA9AA0B011A9822E9191EEB157C0465D9660932553` (DO NOT USE old).
- Pinned SIM evidence: `_build/run_20261026_142450_892/receipt.json`, 15 UART bytes + 2 GPIO patterns, RF ARCHSEL=2.
- Verified IMEM SHA256: `7BEA7D440BCE6C559E3DA6E44ACEA7BE8044C4418D3E7913AB9B6AA51E16A535`.
- New GHDL→Verilog SHA256: `06376173AE0BE1A7EC53724354C427B9674362D9B2A6F397ED499AA3C7E01452`.
- Preliminary Gowin STA: 5466 paths and endpoints, setup violations 0, hold violations 0; minimum reported setup +14.936 ns, hold +0.405 ns, recovery +34.707 ns, removal +1.528 ns.
- `LAB061_FIT_STA_PRELIM_PASS` confirmed; full fitted bank-voltage/IO audit **NOT RUN**.
- Previous FIT before CST revision had clock `clk_i` pin52 reporting BankVccio **1.2** despite LVCMOS33, and thus remained BLOCKED.

### NOW — mandatory read-only audit of EXACT NEW FIT, not another build

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
.\02-NEORV32\tools\audit_fit_lab061.ps1 `
    -FitJob '.\02-NEORV32\_build\fit_20261026_144630_744_c86f33' `
    -ExpectedSHA256 '3E1DC3EB6DC464E3992C733078A564680D5F279E4D89BAA8A47CB9002246FC5F'
```

Required future markers (NOT YET observed for new job): `LAB061_PNR_BANK_VCCIO_PASS` and `LAB061_INTERNAL_PREBOARD_AUDIT_PASS`. If audit fails, share first failure exactly; do not work around the audit or program the board.

If bank/IO audit PASS, next step is a strictly volatile SRAM-only dry run followed by one user-authorized program with sha-verified `.fs`, then physical UART/LED validation. The external asynchronous UART RX/reset remain noted scope limits. No Flash/SD.

## Контрольная точка — 26.10.2026, после 14:28: полный отчёт ресурсов + выявлен CLOCK BankVccio mismatch

**Независимый операторский read-only аудит оригинального FIT прошёл проверки SHA/исходников/пинов/STA, но обнаружено новое существенное замечание по итоговому PnR отчёту. Уровень проверки повышен, предыдущий «preboard audit PASS» НЕ является разрешением SRAM programming.**

- Был проверен исходный PnR job: `02-NEORV32/_build/fit_20261026_142800_809_767b05`, битстрим `lab061_neorv32_nano9k.fs`, SHA-256 `6BD42615371AFA901C21DADA9AA0B011A9822E9191EEB157C0465D9660932553`.
- `LAB061_INPUT_SNAPSHOT_SHA_PASS`: 57 файлов + ROM + Verilog; `LAB061_PINS_27MHZ_PASS`: 10 назначенных выводов и однодоменная SDC; `LAB061_STA_SCREEN_PRELIM_PASS`: 5466 путей, setup/hold violation=0; setup +14.936 ns / hold +0.405 ns / recovery +34.707 ns / removal +1.528 ns.
- **Resource PnR**: Logic **3228 / 8640 (38%)**; LUT 3052, ALU 122, ROM16 0; Registers **1923 / 6693 (29%)**, Logic FF 1921 / 6480, IO FF 2 / 213; BSRAM **20%**, DSP **0%**, PLL **0/2**; IO=10. Это точные числа операторского отчёта, не оценка.
- Напряжения PnR: UART bank2 3.3 V, reset и LEDs bank3 1.8 V — согласуются с назначениями. **Но clock input `clk_i` pin52 bank1: `IO Type LVCMOS33` и `BankVccio=1.2`!** Для платы Tang Nano 9K 27MHz oscillator на pin52 ожидается 3.3 V. Смотрите эталонный `01-PicoRV32/constraints/tang_nano_9k.cst` и документацию по Tang Nano 9K: [Sipeed wiki](https://github.com/sipeed/sipeed_wiki/blob/main/docs/hardware/zh/tang/Tang-Nano-9K/examples/lushaylabs/1_installation_getting_started/installation_getting_started.md), [схема и BANK_VCCIO example](https://www.weigu.lu/other_projects/fpga/fpga_tang_nano_9k/index.html). Старый PiKoSoL аппаратно работал с pin52 / LVCMOS33, но это **не объясняет** напряжение банка в данном отчёте. Вывод pin52 только вход; остальные 9 сигналов согласованы.
- В новом коммите исправлена **только** строка в `02-NEORV32/constraints/lab061_nano9k.cst`: `IO_PORT "clk_i" IO_TYPE=LVCMOS33 PULL_MODE=NONE BANK_VCCIO=3.3;`. CPU/firmware/IMEM/VHDL wrapper **не менялись**, повторная SIM не нужна.
- `tools/audit_fit_lab061.ps1` доработан: он проверяет уже фактическую колонку `BankVccio` для **всех 10** назначенных портов. Старый отчёт с pin52 BankVccio=1.2 должен теперь получить `LAB061_PNR_BANK_VCCIO_FAIL`. Новая прошивка **не будет допущена к плате**, пока PnR report не подтвердит pin52 BankVccio=3.3.

### Единственная следующая операция — новый FIT с исправленным CST (SRAM запрещена до PASS)

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin
git restore --source origin/main --worktree -- `
    02-NEORV32/README.md `
    02-NEORV32/constraints/lab061_nano9k.cst `
    02-NEORV32/tools/audit_fit_lab061.ps1

.\02-NEORV32\tools\activate_ucrt64.ps1
.\02-NEORV32\tools\fit_lab061.ps1 `
    -SimJob '.\02-NEORV32\_build\run_20261026_142450_892'
```

Сохранить новый `LAB061_FIT_JOB` и новый `LAB061_BITSTREAM_SHA256`. Потом с **новым** SHA-256:
```powershell
.\02-NEORV32\tools\audit_fit_lab061.ps1 `
  -FitJob 'НОВЫЙ_ПУТЬ_ИЗ_LAB061_FIT_JOB' `
  -ExpectedSHA256 'НОВЫЙ_SHA256_ИЗ_LAB061_BITSTREAM_SHA256'
```

Только `LAB061_PNR_BANK_VCCIO_PASS` плюс `LAB061_INTERNAL_PREBOARD_AUDIT_PASS` позволяют планировать осторожный SRAM-only smoke (без Flash/SD). Если Gowin откажет явному BANK_VCCIO=3.3, не удалять ограничение и не программировать старый `.fs`; сохранить первую ошибку и обсудить отдельно. Обязательное отдельное замечание: UART RX асинхронен, reset внешний; это не означает, что все внешние временные параметры охвачены SDC.

## Контрольная точка — 26.10.2026, 14:28: ARCHSEL=2 Gowin PnR PASS / STA PRELIM PASS

**Оператор предоставил результат второй попытки LAB-06.1C (на физической FPGA пока НЕ запускали):**

- FIT job: `02-NEORV32/_build/fit_20261026_142800_809_767b05`.
- SIM evidence (RF ARCHSEL=2): `02-NEORV32/_build/run_20261026_142450_892/receipt.json`.
- ROM image SHA256: `7BEA7D440BCE6C559E3DA6E44ACEA7BE8044C4418D3E7913AB9B6AA51E16A535`.
- GHDL→Verilog SHA256: `4A0084C2F4EE4DE455D42EA2C0B91AD5324CE59E54D75C24D71443DAE0E0A7FA`.
- **PnR produced** `lab061_neorv32_nano9k.fs`; exact SHA256 **`6BD42615371AFA901C21DADA9AA0B011A9822E9191EEB157C0465D9660932553`**.
- Preliminary STA: **5466 paths/endpoints**, setup violations **0**, hold violations **0**; displayed minimum slacks setup **+14.936 ns**, hold **+0.405 ns**, recovery **+34.707 ns**, removal **+1.528 ns**.
- `LAB061_STA_SCREEN_PRELIM_PASS`; `LAB061_FIT_STA_PRELIM_PASS`; `LAB061_BOARD_NOT_RUN`.
- **The previous `PA2122` on RF ARCHSEL=0 is resolved for the new candidate.** No board pass is claimed, and no resource totals have yet been transcribed from the actual `.rpt.txt`.

### NEXT — read-only resource/pin/STA audit before hardware

A new **`02-NEORV32/tools/audit_fit_lab061.ps1`** checks exact bitstream/SIM SHA256 provenance, staged inputs, 10 CST pin numbers/types (cross-checked against PicoRV32), the single 27 MHz SDC, reruns the STA screen, and prints resources from the Gowin PnR text report. It does **not** modify FPGA, Flash, or SD and does not perform another build.

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin
git restore --source origin/main --worktree -- 02-NEORV32/README.md 02-NEORV32/tools/audit_fit_lab061.ps1
.\02-NEORV32\tools\activate_ucrt64.ps1
.\02-NEORV32\tools\audit_fit_lab061.ps1 `
  -FitJob '.\02-NEORV32\_build\fit_20261026_142800_809_767b05' `
  -ExpectedSHA256 '6BD42615371AFA901C21DADA9AA0B011A9822E9191EEB157C0465D9660932553'
```

If the PowerShell command returns `LAB061_INTERNAL_PREBOARD_AUDIT_PASS`, **still** verify resource fit, all critical warnings, external reset and asynchronous UART RX constraints before SRAM programming. If any audit check fails, keep the exact job and report which check stopped. Avoid another PnR unless a specific issue requires correction. Maximum 2–3 documented physical tests after authorization.

**Comparison note:** architecture `CPU_RF_ARCH_SEL=2` consumes FF-based register file instead of the default BRAM inference; report real LUT/FF/BSRAM rather than estimates, and keep native-SoC and CPU-core comparisons separate.

## Контрольная точка — 26.10.2026, 14:24: ARCHSEL=2 повторная SIM PASS

**Подтверждено оператором на Windows GHDL** после выбора `CPU_RF_ARCH_SEL => 2` в `rtl/lab061_neorv32_top.vhd`. Это отдельный успешный тест новой конфигурации CPU, а не перенос старого SIM PASS.

- Job: `02-NEORV32/_build/run_20261026_142450_892`.
- Протокол: `_build/run_20261026_142450_892/receipt.json`.
- Источник: неизменный NEORV32 upstream commit `b2620454ebb2407e81a6a1965ef52e2a860b0432`.
- RV32I binary **132 bytes**, SHA-256 `8B6E8AD272BB56584D37EEB37484FC778B2B2C796F3F0CA89ED5FE52D532A285`.
- IMEM image SHA-256 `7BEA7D440BCE6C559E3DA6E44ACEA7BE8044C4418D3E7913AB9B6AA51E16A535`. Совпадает с прежним, поскольку изменилась конфигурация аппаратного регистрового файла, а не прошивка.
- Вывод NEORV32: `CPU ISA: rv32ix_zicsr_zifencei`; `CPU tuning options: ... rf_arch=reg` — это именно выбранный `ARCHSEL=2`.
- `LAB061_GHDL_ELAB_OK`; `LAB061_NEORV32_UART_GPIO_TB_PASS: 15 UART bytes, two GPIO patterns`; `LAB061_SIM_PASS` на времени 1451385286 ps (1.451385286 ms).
- Предупреждения `NUMERIC_STD` о metavalues возникли при `@0ms` и на первом такте `@18518ps`; этот UART/GPIO-тестбенч пройден, но это не доказательство отсутствия всех проблем инициализации во всех конфигурациях.
- **Gowin FIT/STA с ARCHSEL=2 ещё не запускались; FPGA SRAM/Flash/SD не тронуты.**

### NEXT — второй Gowin FIT/STA только с новым SIM job

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
.\02-NEORV32\tools\activate_ucrt64.ps1
$SimJob = '.\02-NEORV32\_build\run_20261026_142450_892'
.\02-NEORV32\tools\fit_lab061.ps1 -SimJob $SimJob
```

`fit_lab061.ps1` должен проверить SIM receipt, SHA-256 IMEM и бинарника, SHA исходников VHDL и pinned upstream, затем запустить GHDL→Verilog→Gowin CLI. Не использовать предыдущий job `run_20261026_132020_122`: его VHDL SHA относится к ARCHSEL=0 и должен отвергаться проверкой целостности.

**Следующий критерий:** получение фактического Gowin PnR и отчёта LUT/ALU/FF/BSRAM и STA setup/hold/recovery/removal. Если появляется новый ERROR — сохранить `_build/fit_*/gowin_cli.log` и показать первую ошибку. **Никаких аппаратных загрузок до полного STA/constraints audit.**

## Контрольная точка — 26.10.2026, 14:02: Gowin PA2122 → RF ARCHSEL=2

**Факт по операторскому логу:** LAB-06.1C first PnR/FIT попытка дошла до завершения GowinSynthesis (100%), после чего Gowin при чтении технологического netlist отверг две памяти регистрового файла. Это **не** исчерпание LUT/FF/BSRAM и **не** ошибка firmware/импорта GHDL.

- SIM PASS (первоначальный default RF=0): `_build/run_20261026_132020_122/receipt.json`, 15 UART bytes и 2 GPIO patterns, 1.451385286 ms.
- FIT job первой попытки: `02-NEORV32/_build/fit_20261026_140218_893_f69896`.
- IMEM image SHA256: `7BEA7D440BCE6C559E3DA6E44ACEA7BE8044C4418D3E7913AB9B6AA51E16A535`.
- GHDL→Verilog **PASS**, output SHA256: `6A8E4A8CB94476ED91A37A0A24601802C1718584E9F3060787148A5F2B7EB79D`.
- GowinSynthesis **completed**, subsequent parser **FAIL**: `ERROR (PA2122): regfile_regfile_0_0_s / regfile_regfile_0_1_s (DPB) WRITE_MODE0=2'b10 not supported; use 2'b00 or 2'b01`.
- **No successful PnR, no STA, no FPGA programming**. The first SIM PASS certifies only the old RF architecture, not the next candidate.

**One targeted fix in our VHDL wrapper, not in pinned NEORV32:** `CPU_RF_ARCH_SEL => 2`. NEORV32 upstream `rtl/core/neorv32_cpu_regfile.vhd` defines four alternatives: 0 synchronous SRAM (old incompatible DPB mapping), 1 asynchronous-read SRAM (possible reserve), 2 resettable FF registers (selected now), 3 ASIC latches (do not use on this FPGA). FF use may increase; obtain actual numbers rather than estimates. *Firmware/ROM binary/clock/MMIO are unchanged*. This is a **new hardware configuration**, so rerun SIM before FIT.

### Next exact PowerShell steps — second controlled NEORV32 candidate

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin
git restore --source origin/main --worktree -- 02-NEORV32/README.md 02-NEORV32/rtl/lab061_neorv32_top.vhd
.\02-NEORV32\tools\activate_ucrt64.ps1

# MUST receive a new LAB061_SIM_PASS before fitting the changed CPU architecture:
.\02-NEORV32\tools\run_lab061.ps1 -Mode Sim

# Only after the new SIM PASS, select the latest NEW sim evidence:
$SimJob = (Get-ChildItem '.\02-NEORV32\_build' -Directory -Filter 'run_*' |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
$receipt = Get-Content (Join-Path $SimJob 'receipt.json') -Raw | ConvertFrom-Json
if ($receipt.Simulation -ne 'PASS') { throw 'SIM not PASS - do not run Gowin' }

.\02-NEORV32\tools\fit_lab061.ps1 -SimJob $SimJob
```

**Critical:** The old `run_20261026_132020_122` receipt will be rejected by `fit_lab061.ps1` after wrapper change because input SHA256 differs. Do not bypass the integrity gate or patch Gowin-generated Verilog/netlists with hard-coded DPB WRITE_MODE values.

**Outcome statuses to record next:** `LAB061_SIM_PASS` for ARCHSEL=2 (not yet observed), then `LAB061_GHDL_TO_VERILOG_PASS`, then Gowin PnR, real STA slacks and resource report. An STA screen PRELIM_PASS alone is not a board acceptance. If new fitting fails, retain the log, share the first ERROR and last 30 lines, and enforce the 1–2 day bring-up stop rule.

## Контрольная точка — 26.10.2026, 13:20: SIM PASS; FIT/STA NEXT

**Подтверждено самим оператором на Windows/GHDL, не из исходников или предварительных оценок.**

- `LAB061_NEORV32_UART_GPIO_TB_PASS: 15 UART bytes, two GPIO patterns`.
- Simulation finished at **1451385286 ps = 1.451385286 ms**.
- `LAB061_SIM_PASS: pinned real NEORV32 CPU executed RV32I binary; UART bytes and GPIO patterns matched`.
- SIM receipt: `C:\GitHub\Sipeed-FPGA\02-NEORV32\_build\run_20261026_132020_122\receipt.json`. Проверенные SHA-256 записаны в нём и должны быть считаны оттуда, а не придуманы.
- `LAB061_NO_BOARD_ACTION`: не было Gowin FIT/STA, загрузки SRAM или записи Flash/SD.
- Source pin: `b2620454ebb2407e81a6a1965ef52e2a860b0432`; toolchain READY.

**LAB-06.1C NEXT:** подготовлен новый `tools/fit_lab061.ps1` (в GitHub), в отдельном `_build/fit_*` он проверяет исходный SIM receipt, образ IMEM SHA, SHA исходников и immutable upstream, делает `GHDL synth --out=verilog`, Gowin CLI PnR и отдельный предварительный STA screen. **Скрипт не программирует FPGA и не пишет ни Flash, ни SD.** Поскольку запуск на Windows ещё не произведён, FIT/STA статус **NOT RUN** и новых PASS нет.

### Команда продолжения — Gowin FIT/STA

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin
git restore --source origin/main --worktree -- `
  02-NEORV32/README.md `
  02-NEORV32/tools/fit_lab061.ps1 `
  02-NEORV32/tools/check_sta_lab061.py

.\02-NEORV32\tools\activate_ucrt64.ps1
.\02-NEORV32\tools\fit_lab061.ps1 -SimJob '.\02-NEORV32\_build\run_20261026_132020_122'
```

**Важные риски первой PnR-попытки:** преобразование VHDL-2008 в Verilog через GHDL, вывод BRAM для ROM, синтез исходного NEORV32 на Gowin 1.9.9Beta-4 и STA. Если ошибка, прислать `LAB061_FIT_JOB` и последние строки `ghdl_synth.log` или `gowin_cli.log`. Не снижать частоту и не менять аппаратную конфигурацию в обход отчёта. `LAB061_STA_SCREEN_PRELIM_PASS` всё ещё не равно независимому полному STA/CDC аудиту или BOARD PASS.

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

**Последний документированный шаг (26.10.2026, 14:24):** оператор получил GHDL SIM PASS для `ARCHSEL=2` с подтверждёнными SHA-256 firmware/IMEM. Предыдущая PA2122 относится к ARCHSEL=0. Следующий gate — вторая Gowin FIT/STA, аппаратная плата не тронута. Старые preflight сохранены как история выше.

**NOW / NEXT:** toolchain готов, SIM PASS получен для ARCHSEL=2. Запустить `fit_lab061.ps1 -SimJob '.\02-NEORV32\_build\run_20261026_142450_892'`, затем изучить фактические ресурсы и STA. Программатор не запускать до полного аудита. Затем в отдельном изолированном каталоге `02-NEORV32/rtl/` создать минимальную VHDL обвязку и тестовую программу `NEORV32 READY`, аккуратно связать `IMEM image` с полученным ПО, собрать реальную симуляцию.

**После каждого этапа:** заменить `NOT RUN` на фактические результаты с датой, commit, версией Gowin, input SHA, .fs SHA, STA отчётом, тестовым UART логом. Отдельные отчёты в `02-NEORV32/acceptance/`; большие локальные отчёты в игнорируемой `02-NEORV32/_reports/`.

## English: handoff summary

LAB-06 is starting with a **pinned upstream VHDL NEORV32** on Tang Nano 9K, 27 MHz, **direct boot from an initialized on-chip IMEM image** (BOOT_MODE_SELECT=2). Enable minimal UART0 and six GPIO outputs, with optional processor features, external Flash, HDMI, SD and Zephyr disabled. Start with the supplied read-only preflight, then **simulation → Gowin PnR/STA → no more than three board checks**. As of 2026-10-26, LAB-06.1B GHDL UART/GPIO simulation PASS, LAB-06.1C Gowin PnR and preliminary STA PASS for the new voltage-constrained candidate. The new image awaits full fitted bank-voltage audit; FPGA BOARD is NOT RUN. Later compare **matched PicoRV32 vs NEORV32 CPU-only, native-SoC and shared-IP** configurations, including independent ALU/register-file/decoder and standard GPIO/UART/timer/SPI block tests. Update this README as the canonical next-session checkpoint.

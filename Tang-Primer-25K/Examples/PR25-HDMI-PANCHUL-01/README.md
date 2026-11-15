# PR25-HDMI-PANCHUL-01 — Tang Primer 25K / PMOD DVI / цветные полосы

**Статус 15.11.2026: GOWIN CLI BUILD PASS / STA NOT REVIEWED / BOARD NOT TESTED.** Пользователь выполнил исправленный `Build_Original.ps1` с исходниками Панчула и получил реальный `.fs`. Загрузки на плату на момент сообщения ещё не было; сценарий сам не обращается к FPGA / Flash.

**Подтверждение сборки (операторский вывод, 15.11.2026, 14:58:52):**
- `CLI BUILD PASS: C:\GitHub\PR25-HDMI-PANCHUL-01\Tang-Primer-25K\Examples\PR25-HDMI-PANCHUL-01\work\impl\pnr\pr25_panchul_hdmi.fs`
- SHA256: `7aab221d20f8851ff8e0689437975df193461c1a0847e532a9f11644eee904ef`
- Gowin log: `evidence/PR25_PANCHUL_BUILD_20261115_145841.log` (только локально у оператора)
- `TIMING: NOT REVIEWED; BOARD: NOT TESTED; NO FPGA WRITES PERFORMED`
- Пиннинг upstream commit `817bd4dac8ab45d5c22bdd78b441bedb80672cd0`; рабочая версия нашего сценария `31ff43b` с правильным вложенным `dvi_tx/dvi_tx.v` / `DVI_TX_Top`.

**Критерий следующего шага:** опытная загрузка в **SRAM** (Gowin Programmer `--run 2`, без Flash), наблюдение устойчивых цветных полос 640×480 и независимый разбор STA. Пока нет аппаратного VIDEO BOARD PASS.



## Что собираем

Оригинальные SystemVerilog-файлы учебного курса **Юрия Панчула**, [basics-graphics-music](https://github.com/yuri-panchul/basics-graphics-music), строго зафиксированный upstream commit **817bd4dac8ab45d5c22bdd78b441bedb80672cd0**. Лицензия самого учебного кода MIT; Gowin DVI_TX поставляется как защищённый IP производителя.

- [HDMI/DVI-конфигурация плат](https://github.com/yuri-panchul/basics-graphics-music/tree/817bd4dac8ab45d5c22bdd78b441bedb80672cd0/boards/tang_primer_25k_pmod_hdmi): `board_specific_top.sv`, `board_specific.cst`, `board_specific.sdc`, PLL и Gowin DVI_TX.
- [Общий wrapper для Primer 25K](https://github.com/yuri-panchul/basics-graphics-music/blob/817bd4dac8ab45d5c22bdd78b441bedb80672cd0/boards/tang_primer_25k_pmod_vga/board_specific_top.sv) подключается оригинальной директивой `include`; в нём находится `DVI_TX_Top` с входами RGB/HSYNC/VSYNC/DE.
- [Генератор видеосинхронизации](https://github.com/yuri-panchul/basics-graphics-music/blob/817bd4dac8ab45d5c22bdd78b441bedb80672cd0/peripherals/vga.sv) и [исходный генератор цветных полос](https://github.com/yuri-panchul/basics-graphics-music/blob/817bd4dac8ab45d5c22bdd78b441bedb80672cd0/labs/2_graphics/2_3_color_stripes/lab_top.sv).
- 640×480, RGB888, пиксельный такт около 25 МГц, сериализатор около 125 МГц. На разъёме будет **DVI-видеосигнал по HDMI-кабелю, без аудиопотока**.
- Физические TMDS пары из исходного CST: clock **H5/J5**, D0 **H8/H7**, D1 **G7/G8**, D2 **F5/G5**. Совпадают по FPGA пинам с нашим подтверждённым A2600 Golden, но DVI модуль устанавливать строго в положение этого проверенного эталона, а не по неоднозначным надписям PMOD в комментариях.

**Оригинальная лаборатория** также включает TM1638 и I2S-вывод; они будут присутствовать в сборке исходного wrapper, но **не являются предметом теста**. Наличие работоспособной графики на экране не доказывает правильность PMOD для иной периферии. В этой версии мы намеренно не переписываем исходный Verilog ради удаления этих частей.

## Реальный первый запуск: BUILD FAIL / EX3937 (15.11.2026)

Пользователь выполнил оригинальный сценарий: **PREPARE PASS**, исходники Панчула `817bd4d...` и 35 исходных файлов прочитаны. Синтез остановился на `ERROR (EX3937): Instantiating unknown module 'DVI_TX_Top'`, `board_specific_top.sv:311`; **FS не создан**.

Диагноз: исходный `dvi_tx.v` — **защищённый Gowin IP**, его нельзя подключать как простой Verilog. В сценарии ревизии 2 удалено прямое `add_file` этого зашифрованного RTL, добавлены `read_ipc` и `generate_target` для конфигурации `dvi_tx.ipc`, скопированной в отдельную рабочую папку. Оригинальный RTL не изменён. **Исправленный сценарий ещё не проверен на Windows / Gowin; BUILD PASS не заявлен.** Лог первой попытки локально у оператора: `evidence/PR25_PANCHUL_BUILD_20261115_143936.log`.

Для копии проекта, которая **уже извлечена в** `C:\GitHub\PR25-HDMI-PANCHUL-01`, не запускать `git pull` в старом рабочем дереве: там конфликты и другая ветка. Обновить один скрипт с GitHub:

```powershell
$script = 'C:\GitHub\PR25-HDMI-PANCHUL-01\Tang-Primer-25K\Examples\PR25-HDMI-PANCHUL-01\Build_Original.ps1'
$backup = "$script.before_ipc_fix"
if (!(Test-Path -LiteralPath $backup)) {
    Copy-Item -LiteralPath $script -Destination $backup
}
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/AIDevelopersMonster/Sipeed-FPGA/main/Tang-Primer-25K/Examples/PR25-HDMI-PANCHUL-01/Build_Original.ps1' -OutFile $script
& $script
```

## Повторная сборка — исправление выбора IP (15.11.2026)

- Попытка 1: `EX3937: unknown module DVI_TX_Top`. Причина в нашем сценарии: был выбран корневой `dvi_tx.v`, где `dvi_tx.ipc` задаёт `module=dvi_tx` (не совпадает с wrapper).
- Попытка 2: `invalid command name "read_ipc"`. Причина в нашем сценарии: команда не поддерживается установленной Gowin 1.9.9 Beta-4.
- **Попытка 3, скрипт GitHub commit `31ff43b`:** использует только оригинальный вложенный `boards/tang_primer_25k_pmod_hdmi/dvi_tx/dvi_tx.v`, с `dvi_tx/dvi_tx.ipc`, где `module=DVI_TX_Top`, `USING_EXTERNAL_CLOCK=true`, `ELVDS=true`. Убраны неподдерживаемые Tcl-команды, не менялся RTL. **BUILD ещё не запущен и не подтверждён.**

Внимание: `dvi_tx/dvi_tx.vo` — post-PnR simulation netlist, не используется как исходный RTL для синтеза.

Для изолированного проекта `C:\GitHub\PR25-HDMI-PANCHUL-01` обновить **только** `Build_Original.ps1` через `Invoke-WebRequest` из `main`, затем выполнить `& $script`. История предыдущих неудачных сборок остаётся локально в `evidence/`. Не записывать FPGA до появления `.fs`, просмотра STA и отдельного операторского подтверждения.

## Запуск на операторском Windows PC (PowerShell 7)

Из каталога `C:\GitHub\Sipeed-FPGA` после `git pull --ff-only`:

```powershell
$pr = 'C:\GitHub\Sipeed-FPGA\Tang-Primer-25K\Examples\PR25-HDMI-PANCHUL-01'
& (Join-Path $pr 'Build_Original.ps1')
```

**Действия сценария:** `git clone` в локальный `_vendor`, `git sparse-checkout` ровно нужных папок, проверка upstream HEAD (без изменения исходников), формирование `work/build_panchul_hdmi.tcl`, запуск **Gowin gw_sh.exe** в `work` (опция `-PrepareOnly` позволит подготовить проект без сборки), сохранение `evidence/*.log`, `work/manifest.json`, проверка нового `work/impl/pnr/pr25_panchul_hdmi.fs` и его SHA256.

Сборка запускается штатной установленной **Gowin 1.9.9Beta-4 Education** и исходными компонентами по зафиксированному коммиту. Проект **ещё не был фактически собран и не протестирован**. Если в текущем Gowin защищённый DVI IP не поддерживается, совместимость проверяется по реальному логу; произвольных изменений RTL/SDC/PLL не делать.

После успешной сборки **обязательно проверить полный STA** и сообщения Gowin. Вывод `CLI BUILD PASS` означает существование новой `.fs`, **не** отсутствие временных нарушений и **не BOARD PASS**.

## Никакой автоматической прошивки

Новый `.fs` пока **не программируем автоматически**; ранее рабочая PR25-13 сохраняется как контрольный образ. Для дальнейшей отдельной проверки, **после обзора STA**, можно использовать существующий путь Gowin Programmer **только SRAM (`--run 2`)**, без Flash. Критерий аппаратного **VIDEO BOARD PASS** — появление стабильных цветных полос на экране.

## Граница утверждений

- **SOURCE REVIEW:** оригинал Панчула имеет для Primer 25K рабочую учебную схему RGB→DVI и набор зависимостей.
- **PREPARE:** создан отдельный воспроизводимый сценарий для Gowin; ещё не прогнан на Windows оператором.
- **BUILD / STA / BOARD:** **не проверены**. Не приписывать этому новому проекту действующий статус рабочего релиза.
- Аудио, USB Host, UART и SDRAM не являются целями эксперимента.
- Существующие **VIDEO+AUDIO BOARD PASS** A2600 Golden и PR25-13 документированы отдельно в [PMOD DVI: проверенные проекты](../../PMOD/DVI/WORKING_PROJECTS_RU.md).

**Ограничения:** защищённый Gowin IP, версия среды, точная разводка разъёма, не проверенная ещё новая сборка. Дальнейшие действия зависят от реального Gowin build log и STA, без предположения об успехе.

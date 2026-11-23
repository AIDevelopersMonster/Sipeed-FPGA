# PiKoSoL TP20 — запуск FPGA, монитора и File Manager (SRAM only)

**Плата:** Sipeed Tang Primer 20K с Dock (пример: Dock V3714).  
**Система:** Windows, PowerShell 7, Gowin Programmer, Python 3 + `pyserial`.  
**Режим:** **только SRAM Program (`--run 2`). FPGA Flash не записываем.**

Эта методичка описывает фактически применявшийся порядок восстановления PiKoSoL:

1. загрузка готовой `.fs` в SRAM FPGA;
2. загрузка `monitor.bin` через UART / XMODEM-CRC;
3. проверка `INFO` в терминале;
4. закрытие UART-консоли и запуск File Manager;
5. при необходимости — запуск RAM-приложения `.bin`.

**Статус:** инструкция основана на операторском сценарии для локальной GPIO-сборки V3714; это **не** публикация самой GPIO-прошивки и **не** заявление о полном BOARD PASS всех периферийных устройств. Исходные проверенные `.fs`, `monitor.bin` и `demo.bin` в соседнем `firmware/` не заменяются. Параметры ниже — *пример конкретной установки*, а не универсальные пути или номера портов.

> **Новый рекомендованный путь для скачанного ZIP:** [START_HERE_RU.md](../START_HERE_RU.md) — `START_PiKoSoL.cmd` из каталога проекта. Ниже оставлена подробная ручная методика для инженерной диагностики; её блоки используют переменные одного окна PowerShell.

## 0. Настройки: заменить на свои

Выполните **этот блок один раз** в PowerShell 7. Следующие команды рассчитаны на **то же окно PowerShell**, где значения переменных сохраняются.

```powershell
# === НАСТРОЙКИ ПОД ВАШ ПК И ПЛАТУ: ЗАМЕНИТЕ ПРИ НЕОБХОДИМОСТИ ===

# Файл конфигурации FPGA (.fs).
# Пример оператора: C:\Users\74095\Downloads\PiKoSoL_TP20_GPIO_V3714\PiKoSoL_TP20_GPIO_V3714.fs
$fs = Join-Path $env:USERPROFILE 'Downloads\PiKoSoL_TP20_GPIO_V3714\PiKoSoL_TP20_GPIO_V3714.fs'

# Путь к установленному Gowin Programmer; версия и каталог у вас могут отличаться.
$programmer = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe'

# ОЖИДАЕМЫЙ SHA256 ИМЕННО ЭТОЙ .fs. Если меняете $fs, обязательно
# задайте контрольную сумму своего проверенного файла, а не отключайте проверку.
$expected = '7B8B8675EF14D7404E4EF26233BB3BDCE1936449136C56BCFC5497B068421F24'

# FPGA модели Tang Primer 20K. Для другой модели измените после проверки платы.
$fpgaDevice = 'GW2A-18C'

# COM-порт USB-JTAG/UART Dock и скорость монитора; COM10 — пример оператора.
$serialPort = 'COM10'
$baud = 115200

# Локальный каталог host_console.py, monitor.bin и demo.bin.
# Пример: %TEMP%\PiKoSoL_TP20_UART
$dir = Join-Path $env:TEMP 'PiKoSoL_TP20_UART'

# Где искать установленный File Manager (можно указать другой каталог).
$fileManagerSearchRoot = Join-Path $env:USERPROFILE 'Downloads'

# Требуемая версия локального менеджера.
# Если используете другую версию, замените регулярное выражение.
$fileManagerVersionPattern = "APP_VERSION = '0\.2\.0"

# Необязательный тестовый RAM-файл; это локальный файл, не часть основного firmware/.
$ledBin = Join-Path $env:USERPROFILE 'Downloads\TP20_GPIO_V3714\TP20_GPIO_V3714\generated\TP20_GPIO_LED_CHASE.bin'
```

**Важное различие:** `GW2A-18C`, `COM10`, имена каталогов и SHA256 выше относятся к конкретному примеру. Параметр `--run 2` **не меняйте**: здесь он отвечает за программирование SRAM, без записи Flash.

Перед работой закройте File Manager, MobaXterm, `host_console.py` и все другие программы, которые могут занимать указанный COM-порт. **Не запускайте два UART-клиента одновременно.**

## 1. Программируем FPGA — только SRAM

```powershell
if (!(Test-Path -LiteralPath $fs -PathType Leaf)) {
    throw "Прошивка не найдена: $fs"
}
if (!(Test-Path -LiteralPath $programmer -PathType Leaf)) {
    throw "Gowin Programmer не найден: $programmer"
}
if ($expected -notmatch '^[0-9a-fA-F]{64}$') {
    throw 'Укажите полный SHA256 (64 шестнадцатеричных символа)'
}

$hash = (Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash
if ($hash -ne $expected) {
    throw "SHA256 не совпадает: $hash"
}

Write-Host 'FIRMWARE HASH PASS' -ForegroundColor Green

# ТОЛЬКО SRAM Program, НЕ Flash.
& $programmer --device $fpgaDevice --run 2 --fsFile $fs

if ($LASTEXITCODE -ne 0) {
    throw "PROGRAM FAILED (exit $LASTEXITCODE)"
}
Write-Host 'SRAM PROGRAM CLI PASS' -ForegroundColor Green
```

Ожидаемый фрагмент журнала:

```text
Operation "SRAM Program" for device#1...
Programming...: [#########################] 100%
```

**Внимание:** сообщение `SRAM PROGRAM CLI PASS` означает, что CLI завершился успешно. Полную работоспособность платы дополнительно подтверждают UART и HDMI на следующих этапах. После **полного отключения питания** SRAM-конфигурацию может понадобиться загрузить заново.

## 2. Подготавливаем файлы UART-загрузчика

В `$dir` должны находиться **три файла**: `host_console.py`, `monitor.bin` и `demo.bin`.

Если они уже есть, повторное скачивание **не требуется**. Если отсутствуют, следующий блок скачает **только отсутствующие** файлы из `main` репозитория PiKoSoL, не затрагивая `.fs`:

```powershell
$base = 'https://raw.githubusercontent.com/AIDevelopersMonster/Sipeed-FPGA/main/Tang-Primer-20K/Examples/PR20-03-PiKoSoL-KonSol'

if (-not $dir) { $dir = Join-Path $env:TEMP 'PiKoSoL_TP20_UART' }
New-Item -ItemType Directory -Force -Path $dir | Out-Null

$needed = @{
    'host_console.py' = "$base/tools/host_console.py"
    'monitor.bin'     = "$base/firmware/monitor.bin"
    'demo.bin'        = "$base/firmware/demo.bin"
}

foreach ($name in $needed.Keys) {
    $target = Join-Path $dir $name
    if (!(Test-Path -LiteralPath $target -PathType Leaf)) {
        Invoke-WebRequest -Uri $needed[$name] -OutFile $target
        Write-Host "DOWNLOADED: $target"
    }
}

# Контроль целостности известного монитора и demo из PiKoSoL TP20.
$monitorHash = (Get-FileHash -LiteralPath "$dir\monitor.bin" -Algorithm SHA256).Hash
$demoHash = (Get-FileHash -LiteralPath "$dir\demo.bin" -Algorithm SHA256).Hash

if ($monitorHash -ne '414D8B9859CE95826E9A0BA12A26E820AF2942CD4FD964EA9FF75AC28AE135C7') {
    throw 'MONITOR HASH MISMATCH'
}
if ($demoHash -ne 'BE20FB6EC6D1C7BFE1E9591F0C734649C61D200217F5EBF15800B4F4E681DE26') {
    throw 'DEMO HASH MISMATCH'
}
Write-Host 'MONITOR + DEMO HASH PASS' -ForegroundColor Green
```

При отсутствии зависимости установите её **один раз**: `python -m pip install pyserial`. Во время загрузки COM-порт должен быть свободен.

## 3. Загружаем монитор PiKoSoL (XMODEM-CRC)

После `SRAM Program` FPGA запускает штатный загрузчик. Загружаем монитор:

```powershell
python -B "$dir\host_console.py" `
  --port $serialPort `
  --baud $baud `
  --monitor "$dir\monitor.bin" `
  --demo "$dir\demo.bin"
```

Когда в консоли появится:

```text
Waiting for stock bootloader C
```

**Нажмите кнопку Dock S0 один раз** (пример для указанной ревизии платы).

Ожидается:

```text
XMODEM transfer ACK / PASS
PiKoSoL TP20 / PicoRV32 / UART + HDMI
PiKoSoL>
```

Реальный успех передачи определяется ответом загрузчика и запуском монитора, а не только наличием файла на диске.

## 4. Проверяем монитор

В появившейся PC-консоли `PC>` введите:

```text
INFO
```

Монитор должен ответить информацией о PicoRV32, памяти, UART и видео. При подключённом HDMI результат должен отображаться и на экране.

Затем введите:

```text
:EXIT
```

Это **закрывает ПК-консоль и освобождает COM-порт**, но **не является командой перепрошивки FPGA**. Пока консоль открыта, File Manager не должен подключаться к этому же порту.

## 5. Запускаем установленный PiKoSoL File Manager

В `main` репозитория находится File Manager **v0.1.4**; версия v0.2.0 — в экспериментальной ветке. В новом ZIP рекомендуется открывать File Manager непосредственно из соседнего каталога `FileManager`, без рекурсивного поиска по `Downloads`. 

Непосредственный запуск File Manager после закрытия предыдущей UART-консоли:

```powershell
$fm = Join-Path (Split-Path -Parent $PSScriptRoot) 'FileManager\PiKoSoL_FileManager.py'
# Если вы выполняете команды в корне PR20-03-PiKoSoL-KonSol, используйте:
# $fm = Join-Path (Get-Location).Path 'FileManager\PiKoSoL_FileManager.py'
python -B $fm --root (Split-Path -Parent $fm)\.. --port $serialPort
```

Для ZIP-пользователей предпочтительнее `START_PiKoSoL.cmd`: путь к файлам и COM-порт он передаёт автоматически.



Следующий фрагмент ищет **уже установленную локальную копию** `PiKoSoL_FileManager.py` в указанном каталоге и отбирает нужную версию. Он **ничего не скачивает и не перепрограммирует**.

```powershell
$fm = Get-ChildItem $fileManagerSearchRoot `
  -Recurse -File -Filter 'PiKoSoL_FileManager.py' `
  -ErrorAction SilentlyContinue |
  Where-Object {
      Select-String -LiteralPath $_.FullName `
        -Pattern $fileManagerVersionPattern -Quiet
  } |
  Select-Object -First 1 -ExpandProperty FullName

if (-not $fm) {
    throw "File Manager нужной версии не найден в $fileManagerSearchRoot"
}

Write-Host "START: $fm"
python -B "$fm"
```

**Уточнение о версиях:** в `main` репозитория сейчас находится File Manager **v0.1.4**, а используемый в примере локальный **v0.2.0** — отдельная кандидатная версия. Поэтому поиск по `0.2.0` может ничего не найти на новом ПК; это **не** неисправность платы. При использовании локальной v0.1.4 измените `$fileManagerVersionPattern` на `"APP_VERSION = '0\.1\.4"`. Другие файлы менеджера (`pikosol_core.py`, `pikosol_xmodem.py` и пр.) должны находиться рядом с выбранным `PiKoSoL_FileManager.py`.

В менеджере выберите `$serialPort` и `$baud`, подключитесь к монитору и проверьте `INFO` **до** загрузки приложений.

## 6. Необязательно: проверка GPIO LED

Для локального примера GPIO V3714 укажите менеджеру файл из переменной `$ledBin` через кнопку **«+ Выбрать файл»**, затем **«Загрузить .bin + RUN»**.

**Наблюдение оператора:** `TP20_GPIO_LED_CHASE.bin` выполняется быстро; светодиоды последовательно включаются и в конце выключаются. Для съёмки видео наблюдайте за ними **сразу при запуске**, а не после завершения программы.

Результат `RUN RETURNED TO PiKoSoL` подтверждает возврат программы в монитор, но не гарантирует успех *следующей* передачи XMODEM. При ошибке повторной загрузки (`ACK/NAK timeout`) **не считать повторный запуск PASS**: сохранить лог, проверить доступность команды `INFO` и состояние COM-порта. Не пытаться исправлять ошибку случайной заменой `.fs` или записью во Flash.

## Краткая диагностика

| Симптом | Действие |
| --- | --- |
| `.fs` не найдена / SHA256 не совпадает | Проверить `$fs` и `$expected`; не программировать неизвестный файл |
| Программатор вернул ненулевой код | Остановиться, сохранить вывод CLI, проверить подключение платы |
| `Waiting for stock bootloader C` | Нажать Dock S0 один раз на данной ревизии |
| `COM port access denied` | Закрыть все UART-клиенты, проверить владельца порта; не запускать два клиента |
| В HDMI написано `Waiting for downloader` | Само по себе это не означает запуск монитора; требуется передача через XMODEM |
| `INFO` не отвечает | Не отправлять `.bin`, пока связь с монитором не подтверждена |
| Первый `RUN` прошёл, повторный `LOAD` не прошёл | Сохранить журнал XMODEM; причину не считать установленной |
| Плата полностью обесточивалась | Повторить SRAM-загрузку FPGA и, при необходимости, загрузку монитора |

## Что эта процедура **не** делает

- Не записывает FPGA Flash.
- Не пересобирает RTL и не запускает Gowin Synthesis / Place & Route.
- Не обновляет исходники, `.fs` или бинарные файлы в GitHub.
- Не делает GitHub Release или тег.
- Не превращает временно загруженную RAM-программу в постоянно установленную.

**Источник методики:** практический операторский сценарий PiKoSoL TP20 GPIO V3714, 21 ноября 2026 года. Настройки конкретной Windows-системы вынесены в отдельные переменные, чтобы инструкция была пригодна для другого ПК и соответствующей платы.

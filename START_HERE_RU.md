# Первый запуск линии Sipeed FPGA (Windows 10 / PowerShell 7)

**Этот архив не меняет ваши существующие репозитории и не содержит .git.** Установка идёт в новый каталог `C:\GitHub\Sipeed-FPGA`; репозитории `DDF` и MAX10 не затрагиваются.

## A. Безопасная распаковка

Скачайте `Sipeed-FPGA-Starter-v0.1.0.zip` в стандартную папку Downloads.

```powershell
$zip = Join-Path $HOME 'Downloads\Sipeed-FPGA-Starter-v0.1.0.zip'
$dest = 'C:\GitHub\Sipeed-FPGA'
if (-not (Test-Path -LiteralPath $zip)) { throw "Архив не найден: $zip" }
if (Test-Path -LiteralPath $dest) { throw "Каталог уже существует: $dest. Ничего не перезаписываем." }
New-Item -ItemType Directory -Path 'C:\GitHub' -Force | Out-Null
Expand-Archive -LiteralPath $zip -DestinationPath 'C:\GitHub'
Set-Location $dest
Get-ChildItem -Directory
& .\tools\verify_integrity.ps1
```

## B. Независимая проверка программы (CPU RTL пока не загружен)

```powershell
& .\tools\preflight.ps1
& .\01-PicoRV32\tools\test.ps1 -PythonOnly
```

Ожидается сообщение `ASSEMBLE PASS` и `FIRMWARE MODEL PASS`. Оно доказывает только правильность сборки нашего подмножества RV32I и исполнения его на отдельном программном интерпретаторе.

## C. RTL-симуляция на ПК

Установите Icarus Verilog, чтобы команды `iverilog` и `vvp` находились в `PATH`. После проверки Git и Интернета:

```powershell
& .\01-PicoRV32\tools\fetch_picorv32.ps1
& .\01-PicoRV32\tools\test.ps1
```

Нужны два результата: `UART TB PASS` и `SOC TB PASS`. Если их нет, PnR пока не запускать.

## D. Gowin CLI и плата Nano 9K

```powershell
& .\01-PicoRV32\tools\build_gowin.ps1
```

Скрипт предполагает установку в `C:\Gowin\Gowin_V1.9.9Beta-4_Education`. Если путь иной:

```powershell
& .\01-PicoRV32\tools\build_gowin.ps1 -GowinRoot 'C:\путь\к\Gowin'
```

Проверьте сообщения синтеза, PnR, требуемые выводы, отсутствие нарушений тайминга, соответствие FPGA. Только затем вручную решайте, программировать ли **SRAM**; автоматического программирования в архиве нет.

## E. Публикация после проверки локального результата

```powershell
git init -b main
git add .
git commit -m 'Bootstrap PicoRV32-NEORV32-LiteX-Rocket research line'
gh repo create AIDevelopersMonster/Sipeed-FPGA --public --source . --remote origin --push
```

Эти команды выполняйте **только внутри** `C:\GitHub\Sipeed-FPGA`. `gh repo create` создаёт публичный GitHub-репозиторий и отправляет первый коммит, поэтому перед исполнением проверьте файлы и согласованность публикации. Если имя на GitHub уже занято, не используйте `--force` и не переписывайте чужую историю.

## Что считается завершением первой работы

| Состояние | Критерий |
|---|---|
| MODEL_PASS | Выполнено здесь автором комплекта |
| RTL_PASS | После успешного `test.ps1` на вашей системе |
| PNR_PASS | После чистой сборки и STA для Nano 9K |
| BOARD_PASS | После аппаратного эксперимента и сохранения лога UART/LED |

**Пока ни RTL_PASS, ни PNR_PASS, ни BOARD_PASS не утверждаются.**

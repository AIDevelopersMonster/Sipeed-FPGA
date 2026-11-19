# PR20-04 — NESTang GAME.cmd: выбор NES-игры в Windows

**Плата:** Tang Primer 20K Dock (GW2A-18C). **Статус:** пользователь подтвердил работу меню выбора ROM и отправку игры через COM10, но не аппаратную работу каждой NES-игры по отдельности. Звук не подтверждён.

## Установить GAME.cmd одной командой

Откройте PowerShell и задайте папку своей установленной NESTang:

```powershell
$root = 'C:\Users\74095\Downloads\nestang-0.4' # замените на свою папку
$url = 'https://raw.githubusercontent.com/AIDevelopersMonster/Sipeed-FPGA/main/Tang-Primer-20K/Examples/PR20-04-NESTang-P5-Keyboard/Install-GameMenu.ps1'
Invoke-WebRequest -Uri $url -OutFile (Join-Path $root 'Install-GameMenu.ps1')
pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'Install-GameMenu.ps1') -Root $root
```

Если команда pwsh не найдена, замените её в последней строке на powershell.exe.

Установщик создаёт GAME.cmd и GAME.ps1 и переносит существующие *.nes из корня NESTang и NES_GAMES в games/. Существующие игры не перезаписываются. Повторный запуск не удаляет игры. Скрипт не прошивает FPGA, не меняет Flash и не скачивает NES ROM.

## Файлы

```text
nestang-0.4/
  Install-GameMenu.ps1
  GAME.cmd
  GAME.ps1
  NESTang-Keyboard.exe   # загрузчик нужен отдельно
  games/
    Spacegulls-1.1.nes
    color-match-combat.nes
    ...
```

**NESTang-Keyboard.exe не включён в этот установщик.** Положите ранее полученную программу рядом с GAME.cmd. Она передаёт ROM и кнопки с клавиатуры ПК через COM10 (921600, 8N1). Оригинальный loader.exe автора не изменяется.

## Запуск

Закройте MobaXterm и другие программы, занимающие COM10. Запустите GAME.cmd двойным щелчком и выберите номер игры. ESC завершает программу-контроллер и возвращает к выбору (после Enter). Q — выход из меню.

Управление: стрелки — направления, Z — A, X — B, Enter — START, правый Shift — SELECT.

## Проверки и ограничения

- Пользователь подтвердил меню из девяти игр, выбор color-match-combat.nes и строку Sent 40976 ROM bytes to FPGA.
- Строка Sent ... означает отправку по UART, но не подтверждает запись FPGA в DDR3.
- Игра Spacegulls ранее запускалась с изображением HDMI и управлением (см. основной README); это не доказывает работу всех ROM.
- Звук не проверен. Этот скрипт не создаёт Releases, не публикует ROM или экспериментальные прошивки.

Основа FPGA-эмулятора: [nand2mario/NESTang v0.4](https://github.com/nand2mario/nestang/tree/v0.4). [Основной README PR20-04](README.md).

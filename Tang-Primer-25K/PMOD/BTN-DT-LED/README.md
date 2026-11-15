# PR25-PMOD-01 — BTN + DIGTUBE + LED (проверенный пример)

**Плата:** Tang Primer 25K + Dock. **BOARD PASS:** 13 ноября 2026 года, подтверждение оператором.

Это **один оригинальный проект Sipeed с тремя модулями одновременно**, а не три отдельно испытанные прошивки. Оператор подтвердил, что кнопки меняют показания DT, семисегментный индикатор выводит цифры, а светодиоды реагируют на DIP-переключатели. [Протокол испытаний](../PR25-PMOD-01_SRAM_PROGRAM_PASS_2026-11-13.md) · [видео](https://youtu.be/M-A6kIbpd1M).

## Проверенные функции и исходники

| PMOD | Наблюдаемый результат | Исходник производителя |
| --- | --- | --- |
| BTN (кнопки) | Нажатия изменяют число на DT | [driver_Button.v](https://github.com/sipeed/TangPrimer-25K-example/blob/bc143318de1f397d4a98e19a94a9c23395fcb3d2/pmod_digitalTube-2bit/src/driver_Button.v) |
| DT / DIGTUBE | 2-разрядный 7-сегментный индикатор показывает и изменяет число | [driver_DigitalTube.v](https://github.com/sipeed/TangPrimer-25K-example/blob/bc143318de1f397d4a98e19a94a9c23395fcb3d2/pmod_digitalTube-2bit/src/driver_DigitalTube.v) |
| LED | LED меняются при переключении DIP | [driver_Led.v](https://github.com/sipeed/TangPrimer-25K-example/blob/bc143318de1f397d4a98e19a94a9c23395fcb3d2/pmod_digitalTube-2bit/src/driver_Led.v) |

**Общая связка:** [top_demo.v](https://github.com/sipeed/TangPrimer-25K-example/blob/bc143318de1f397d4a98e19a94a9c23395fcb3d2/pmod_digitalTube-2bit/src/top_demo.v), [точный pinout .cst](https://github.com/sipeed/TangPrimer-25K-example/blob/bc143318de1f397d4a98e19a94a9c23395fcb3d2/pmod_digitalTube-2bit/src/pmod_digitalTube-2bit.cst), [Gowin .gprj](https://github.com/sipeed/TangPrimer-25K-example/blob/bc143318de1f397d4a98e19a94a9c23395fcb3d2/pmod_digitalTube-2bit/pmod_digitalTube-2bit.gprj), [исходный архив .fs.7z](https://github.com/sipeed/TangPrimer-25K-example/blob/bc143318de1f397d4a98e19a94a9c23395fcb3d2/pmod_digitalTube-2bit/pmod_digitalTube-2bit.fs.7z).

## Получить оригинал (без переделки)

Оригинальный код Sipeed закреплён по коммиту `bc143318de1f397d4a98e19a94a9c23395fcb3d2`. [Get_Original_PMOD01.ps1](Get_Original_PMOD01.ps1) загружает RTL, Gowin project, CST и оригинальный архив прошивки в **локальный** `_vendor_original/` и сверяет Git blob SHA каждого файла с upstream. Для запуска из каталога этой лаборатории:

```powershell
.\Get_Original_PMOD01.ps1
```

Полученные файлы не зеркалируются в нашем репозитории: у upstream-репозитория не обнаружена явная лицензия для перепубликации. Новый сценарий получения файлов **ещё не проходил операторский тест**. Он не выполняет сборку и не программирует FPGA.

## Аппаратная установка и повторение

Если USB-A слева, USB-C справа, а PMOD-разъёмы снизу: **BTN слева, DT по центру, LED справа**. Это подтверждено [уточнением разработчика/пользователя в issue #17](https://github.com/sipeed/TangPrimer-25K-example/issues/17). Подключать модули при отключенном питании, сверяя обе строки контактов и ориентацию.

Использовать **оригинальный .fs из архива Sipeed**, без самостоятельной пересборки и без модификации. После распаковки `pmod_digitalTube-2bit.fs.7z` в `_vendor_original/`:

```powershell
$cli = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe'
$fs = (Resolve-Path '.\_vendor_original\pmod_digitalTube-2bit.fs').Path
& $cli --device GW5A-25A --run 2 --fsFile $fs --cable-index 1
if ($LASTEXITCODE -ne 0) { throw "SRAM Program failed: $LASTEXITCODE" }
(Get-FileHash -Path $fs -Algorithm SHA256).Hash
```

Вендорский `.gprj` указывает `GW5A-25A / GW5A-LV25MG121NES`, top `top_demo`. Успешная загрузка `.fs` — только **SRAM PROGRAM PASS**. Функциональный **BOARD PASS** относится к реально наблюдавшимся функциям 13.11.2026. Хэш использованного тогда распакованного `.fs` не был зафиксирован, поэтому нельзя заявлять побайтовую идентичность по одному названию файла. Отдельных BOARD PASS для трёх изолированных IP также нет.

**Состояние проекта:** PAUSED до получения SDRAM; этот документ — сохранение достигнутого положительного результата, не возобновление активных экспериментов.

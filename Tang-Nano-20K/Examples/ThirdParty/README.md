# Tang Nano 20K — nano-Z80 + CP/Mish: прямой запуск (BOARD PASS)

**Аппаратно подтверждено 11 ноября 2026 года:** запуск nano-Z80 в FPGA SRAM, ROM Monitor на COM25/HDMI, загрузка CP/Mish с microSD и интерактивная консоль через COM25. Оператор выполнил `A>DIR` и получил каталог файлов; это **CP/Mish INTERACTIVE BOARD PASS**.

Заводская LiteX во Flash остаётся нетронутой. Работаем с временным образом Z80 в SRAM; после отключения питания плата возвращается к заводской конфигурации.

## Файлы, которые нужны

| Файл | Для чего |
|---|---|
| [restore-nano-z80-after-powercycle.ps1](restore-nano-z80-after-powercycle.ps1) | Запуск FPGA SRAM + временных MS5351 в одном сценарии |
| [program-nano-z80-gowin.ps1](program-nano-z80-gowin.ps1) | Проверенная загрузка `nano-z80.fs` только в FPGA SRAM |
| [tp20-enable-pll-volatile.ps1](tp20-enable-pll-volatile.ps1) | MS5351 O0=25,175 МГц / O1=12 МГц, без постоянного сохранения |
| [download-nano-z80-full-verified.ps1](download-nano-z80-full-verified.ps1) | Получение полного `nano-z80.img` официального релиза |
| **[Прямой путь запуска CP/Mish](CPMISH_START_RU.md)** | Одна последовательность для COM25, S2 и CP/Mish |

Готовый bitstream хранится на ПК оператора: `C:\GitHub\TP20-ThirdParty\downloads\nano-z80.fs`, RAW-образ: `...\downloads\nano-z80.img`. Оба публикуются автором: [venomix666/nano-z80 releases](https://github.com/venomix666/nano-z80/releases/latest).

## Только прямой путь

Закрыть MobaXterm для освобождения COM25. Если сейчас активна заводская LiteX (после выключения питания):

```powershell
Set-Location C:\GitHub\TP20-ThirdParty
.\restore-nano-z80-after-powercycle.ps1 -Port COM25
```

На запросы вводим `SRAM` и `CLOCKS`. **Не записываем FPGA Flash**. После успешного выполнения нажать **S2**, открыть MobaXterm **COM25 115200 8N1**. Должно появиться `nano-Z80 monitor v0.3` / `Ready`.

```text
L
WF633,83
O007F,06
O0000,00
JF600
```

Команда `WF633,83` направляет консоль CP/Mish на UART, а `O007F,06; O0000,00` выключает PIC IRQ, как это делает штатная команда `B`. Без выключения PIC экспериментально наблюдалась остановка после BIOS-баннера. После запуска:

```text
CP/Mish 2.2r0 for nanoZ80
A>DIR
```

Каталог `A:` на физической плате уже прочитан. Команда `B` — штатный запуск в HDMI/USB keyboard режиме, а не в консоли COM25.

## Наш Nano Commander

**Nano Commander NC0 v0.1** — отдельный проект: двухпанельный файловый менеджер `NC0.COM` для CP/Mish через MobaXterm. Первая сборка прошла программные тесты на модели 8080/BDOS; **BOARD PASS NC0 пока не объявлен**. Готовый ZIP с исходниками, `.COM` и автономным скриптом добавления в копию образа предоставлен в переписке; см. [инструкцию Nano Commander](NanoCommander/README.md).

Исторические эксперименты, старые утилиты и длинные диагностические журналы перенесены в `_archive/2026-11-11/`. **В обычный рабочий маршрут они не входят; возвращаться к ним только по явной просьбе «изучи».**

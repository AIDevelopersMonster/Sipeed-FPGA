# Brus-16 Tang Primer 25K — второй автономный звуковой кандидат

Дата проверки: 14 ноября 2026 года.

## Почему выбрали

Оригинал: https://github.com/Papr1ka/brus16
Авторский релиз **Sound update firmware**: https://github.com/Papr1ka/brus16/releases/tag/sfx
Готовый архив для **Tang Primer 25K**: https://github.com/Papr1ka/brus16/releases/download/sfx/tp25k.zip
Размер архива по GitHub Release API: **4 214 200 байт**, дата релиза **13 июля 2026 года**.

В релизе прямо указано "Sound is implemented over HDMI", перечислены образы для Tang Nano 9K / 20K / Primer 25K и игра **gerion (Sound!!!)**. Архив не был извлечён инструментами ChatGPT: **имена файлов внутри ZIP и их индивидуальные SHA256 пока неизвестны**, а звук на нашей физической плате ещё не испытывался.

### Почему это практически лучше NESTang для наших текущих условий

В авторской инструкции https://github.com/Papr1ka/brus16/blob/main/Readme.md сказано: игры записаны во флеш-память (ROM/BRAM) конфигурации `.fs`; для запуска игры из собственного образа **SD-карту можно не устанавливать**. Это проект с 640x480 графикой без framebuffer и собственного небольшого процессора; для HDMI/SFX-теста **внешняя SDRAM и ESP32-S3 не требуются**. Кнопки/контроллер нужны для игры, но не для наблюдения видео и встроенного звукового ядра, если конкретная игра сама воспроизводит звук.

Использовать именно `sfx`-релиз, а не более поздний `sd`-релиз: `sd` содержит общий загрузчик игр с SD и не является прямой заменой пакета индивидуальных звуковых прошивок.

## Аппаратная архитектура Brus-16 (сверено по исходникам)

- Top: https://github.com/Papr1ka/brus16/blob/main/src/brus16_top.sv — `sfx_top`, `sample` 16 бит, `audio_clk`, `dual_channel = {sample, sample}`, `ELVDS_OBUF` x4 и `hdmi`.
- SFX: https://github.com/Papr1ka/brus16/tree/main/src/sfx — 16 осцилляторов, таблица синуса `sine_table.sv`, обновление огибающих; `sfx_controller.sv` — 44 100 Гц.
- HDMI encoder: https://github.com/Papr1ka/brus16/blob/main/src/hdmi/hdmi.sv — реальный HDMI, `DVI_OUTPUT=0` по умолчанию, `AUDIO_RATE=44100` по умолчанию.
- Constraints: https://github.com/Papr1ka/brus16/blob/main/gowin/src/tp25k/25k.cst — P/N дифференциальные пары H8/H7, G7/G8, F5/G5, H5/J5. Совместимо с нашим уже подтверждённым физическим размещением PMOD DVI.
- Build: https://github.com/Papr1ka/brus16/blob/main/gowin/tp25k.tcl; `GW5A-LV25MG121NC1/I0`, SystemVerilog 2017, `use_cpu_as_gpio=1`.
- PLL: https://github.com/Papr1ka/brus16/blob/main/src/pll_generic.sv — 25,2 МГц пиксельный такт и x5 fast clock (номинал 126 МГц); оригинальный P/N-путь сохранён.

Отличия от наших PR25-08..10: отдельная ветка HDMI ядра с режимом 640x480, частотой 44,1 кГц и собственным синтезатором SFX вместо наших 48кГц тонов. Поддержка звука подтверждается автором в релизе, **не нашим BOARD PASS**.

## Безопасное получение и осмотр архива в PowerShell 7

```powershell
$dir = 'C:\GitHub\Sipeed-FPGA\Tang-Primer-25K\ThirdParty\Brus16-SFX'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$zip = Join-Path $dir 'tp25k.zip'
Invoke-WebRequest -Uri 'https://github.com/Papr1ka/brus16/releases/download/sfx/tp25k.zip' -OutFile $zip
(Get-Item $zip).Length
Get-FileHash -Path $zip -Algorithm SHA256
Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $dir 'unpacked') -Force
Get-ChildItem -Path (Join-Path $dir 'unpacked') -File -Recurse |
    Select-Object FullName, Length
```

**Не программировать архив.** Сначала найти из списка Gerion и удостовериться, что файл формата Gowin `.fs`, не ошибочно `.bin` для другой платы. Если есть `gerion`-образ, для следующего теста использовать только FPGA SRAM. Никакого external Flash, firmware BL616 или SD-образа для первого теста.

## Альтернативы с подтверждёнными TP25K .fs в GitHub Releases

- [NanoApple2 1.5](https://github.com/MiSTle-Dev/NanoApple2/releases/tag/1.5): `nanoapple2_tp25k.fs`, 5 174 817 байт, HDMI со звуком и моделью Mockingboard, но нужна настройка companion MCU.
- [VIC20Nano v2.5.0](https://github.com/MiSTle-Dev/VIC20Nano/releases/tag/v2.5.0): `vic20nano_tp25k.fs`, 5 210 412 байт, HDMI со звуком. По README для TP25K требуется PMOD TF-CARD V2 и MCU companion.
- [C64Nano v2.9.12](https://github.com/MiSTle-Dev/C64Nano/releases/tag/v2.9.12): `C64Nano_TP25k.fs`, 6 181 606 байт; C64 SID на HDMI, нужен дополнительный companion и PMOD TF-CARD.
- [NESTang](https://github.com/nand2mario/nestang): HDMI audio 720p, но для Primer25K обязательна **SDRAM**, поэтому сейчас **не приоритет**.
- [thisiseth/tang-primer-25k-spi-io](https://github.com/thisiseth/tang-primer-25k-spi-io): автор демонстрирует HDMI со звуком, но для подачи контента использует ESP32-S3 по SPI, а готового standalone tone `.fs` в релизах нет.

## Правило присвоения статуса

`AUTHOR CLAIM + READY ARCHIVE` — Brus-16 Gerion.
`SOURCE REFERENCE` — исходный RTL с указанием автора.
`BOARD PASS` — только после нашего наблюдения видео и **слышимого звука**.

**Ограничения лицензии:** в исходном репозитории Brus-16 на момент проверки не обнаружен отдельный корневой LICENSE; не копировать чужие авторские исходники в наш каталог без уточнения прав. Этот файл — ссылки, анализ и проверенные метаданные релиза, а не републикация кода.

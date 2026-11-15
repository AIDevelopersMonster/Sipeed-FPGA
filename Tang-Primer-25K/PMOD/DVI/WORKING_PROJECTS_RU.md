# PMOD DVI / HDMI + AUDIO — реальные работающие проекты Tang Primer 25K

**Исправленный реестр испытаний на 15 ноября 2026 года.**

**Подтверждено на Tang Primer 25K + Dock:** видеовывод по PMOD DVI/HDMI и слышимый музыкальный звук работают в заводской A2600Nano v2.5 и в нашей самостоятельной пересборке PR25-13. Ранее встречавшееся в PMOD утверждение «изображение не получено» неверно для проекта в целом: оно относится только к отдельным испытаниям Sipeed SVO и Arcade MCR2.

## Точные проекты, ссылки и результаты

| Проект | Исходник / оригинальный релиз | Изображение | Звук | Подтверждение |
| --- | --- | --- | --- | --- |
| **A2600Nano v2.5 Golden**, сторонняя готовая прошивка | [MiSTle-Dev/A2600Nano](https://github.com/MiSTle-Dev/A2600Nano), [релиз v2.5](https://github.com/MiSTle-Dev/A2600Nano/releases/tag/v2.5), [оригинальный FS](https://github.com/MiSTle-Dev/A2600Nano/releases/download/v2.5/a2600nano_tp25k.fs) | **BOARD VIDEO PASS** | **BOARD AUDIO PASS** | [PR25-11: успешное контрольное восстановление Golden](../../Examples/PR25-11-A2600-ORIGINAL-REBUILD/README.md) |
| **PR25-13**, собственная работающая пересборка A2600Nano | [Исходники/сборка PR25-13](../../Examples/PR25-13-A2600-SDC-DUTY50/README.md) | **BOARD VIDEO PASS** — анимированная заставка | **BOARD AUDIO PASS** — слышимая мелодическая музыка | [Паспорт рабочей прошивки](../../Examples/PR25-13-A2600-SDC-DUTY50/WORKING_FIRMWARE.md), [манифест](../../Examples/PR25-13-A2600-SDC-DUTY50/working_firmware_manifest.json) |
| **Brus-16 SFX**, включая Gerion, сторонние выпуски | [Papr1ka/brus16](https://github.com/Papr1ka/brus16), [релиз sfx](https://github.com/Papr1ka/brus16/releases/tag/sfx), [архив TP25K](https://github.com/Papr1ka/brus16/releases/download/sfx/tp25k.zip) | **BOARD VIDEO PASS** у всех оператором испытанных FS | **AUDIO NOT HEARD**, несмотря на объявленную поддержку звука | [Операторский отчёт Brus-16](../../ThirdParty/Brus16-SFX/README.md) |
| **PR25-08, 09, 10**, наши тесты интерфейса | [PR25-08](../../Examples/PR25-08-HDMI-AUDIO-GOLDEN/README.md), [сводка PR25-08..10](../../Examples/PR25-10-HDMI-AUDIO-PACKET-PROBE/RESULTS_RU.md) | **BOARD VIDEO PASS** — полосы и диагностические флаги | **AUDIO FAIL** — звук не услышан | Указанные аппаратные протоколы |
| **Sipeed SVO, Arcade MCR2**, отдельные сторонние FS | [Sipeed HDMI/SVO](https://github.com/sipeed/TangPrimer-25K-example/tree/main/hdmi/svo), [Arcade MCR2](https://github.com/alanswx/Arcade-MCR2-TangFPGA/tree/main/mcr2_primer25k) | **Именно в этих испытаниях изображения не получили** | Не подтверждено | [История этих испытаний](README.md) |

## Рабочий эталон: A2600Nano v2.5

- [Точная версия исходников A2600Nano (705bf787...)](https://github.com/MiSTle-Dev/A2600Nano/tree/705bf787675579721d339806cb522905dec73ed3).
- [Инструкция для Tang Primer 25K и PMOD](https://github.com/MiSTle-Dev/A2600Nano/blob/v2.5/TANG_PRIMER_25K.md).
- [Полный Gowin build_tp25k.tcl](https://github.com/MiSTle-Dev/A2600Nano/blob/v2.5/build_tp25k.tcl).
- [Видеотракт video.v](https://github.com/MiSTle-Dev/A2600Nano/blob/v2.5/src/misc/video.v), [HDMI и аудиопакеты hdmi.sv](https://github.com/MiSTle-Dev/A2600Nano/blob/v2.5/src/hdmi/hdmi.sv), PLL, serializer/OSER10 и согласованные ограничения составляют целую зависимую цепочку.
- Оригинальный Golden FS от автора: **SHA256 531b786061cc3b428d829e9f445787d20c6f847645031e3a0a57f64d58ba4aff**. Оператор подтвердил повторное появление изображения и звука при восстановлении Golden после неработающей пересборки PR25-11.

## Наш собственный аппаратно подтверждённый результат PR25-13

**Дата:** 15.11.2026. **FPGA:** GW5A-25A. **Gowin:** 1.9.9Beta-4 Education. **Метод:** только SRAM.

- Рабочий файл: **a2600nano_tp25k_SDC50.fs**.
- **SHA256 22cabb286d0b2ffb0973ae5109c872239782d341cfe46a8792921ed5be37580a**.
- **Видео:** заставка с анимацией отдельных элементов; полноценный игровой процесс не проверялся.
- **Аудио:** отчётливо слышимая мелодическая музыка в стиле игровых приставок.
- Операторская копия бинарника находится **локально** в каталоге PR25-13/artifacts, **не опубликована на GitHub**. См. [инструкцию резервного сохранения](../../Examples/PR25-13-A2600-SDC-DUTY50/WORKING_FIRMWARE.md).

PR25-13 содержит два изменения относительно раннего неработающего PR25-11: синхронизация снятия reset OSER10 и изменение модели waveform в SDC. **Причинная роль каждого изменения не установлена**. Предупреждения STA TA1123/TA1117 остаются открытыми. Реальный BOARD PASS не следует путать с завершённым timing sign-off.

## Правильный технический вывод

**Плата и PMOD DVI/HDMI работоспособны для видео и звука в конкретных проверенных конфигурациях.** Отсутствие SDRAM не помешало получению этих результатов.

**Не завершено:** обособление повторно используемого HDMI/audio IP, интеграция с собственным терминалом, UART, USB Host и PiKoSoL. Неудача изоляции компонентов не отменяет работающих образцов.

**Статус:** проект приостановлен до получения SDRAM; после получения модуля работа возобновляется. Здесь сохранены существующие подтверждённые результаты, новых прошивок или новых BOARD PASS не заявлено.

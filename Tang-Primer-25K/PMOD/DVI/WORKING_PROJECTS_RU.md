# PMOD DVI / HDMI + AUDIO — реальные работающие проекты Tang Primer 25K

**Обновление 17.11.2026: повторная проверка PR25-13 не дала изображения; эксперимент отозван как воспроизводимая рабочая прошивка.**

**Подтверждено на Tang Primer 25K + Dock:** видеовывод по PMOD DVI/HDMI и слышимый звук ранее получены на оригинальной A2600Nano v2.5 Golden. PR25-13 однажды отмечалась как работающая по отчёту оператора, но при повторной загрузке SHA256-совпадающего образа изображение не появилось; статус BOARD PASS отозван до воспроизведения. Ранее встречавшееся в PMOD утверждение «изображение не получено» неверно для проекта в целом: оно относится только к отдельным испытаниям Sipeed SVO и Arcade MCR2.

## Точные проекты, ссылки и результаты

| Проект | Исходник / оригинальный релиз | Изображение | Звук | Подтверждение |
| --- | --- | --- | --- | --- |
| **PR25-KonSol-DVI**, наш статический 80×30 RGB-экран | [Паспорт и сборка](../../Examples/PR25-KonSol-DVI/README.md) | **BOARD VIDEO PASS** — фотографии оператора, 15.11.2026 | **Нет HDMI-аудио (DVI)** | Закрытый Gowin DVI_TX + собственный RGB-генератор; [.fs](../../Examples/PR25-KonSol-DVI/fs/pr25_konsol_trial.fs) опубликован |
| **A2600Nano v2.5 Golden**, сторонняя готовая прошивка | [MiSTle-Dev/A2600Nano](https://github.com/MiSTle-Dev/A2600Nano), [релиз v2.5](https://github.com/MiSTle-Dev/A2600Nano/releases/tag/v2.5), [оригинальный FS](https://github.com/MiSTle-Dev/A2600Nano/releases/download/v2.5/a2600nano_tp25k.fs) | **BOARD VIDEO PASS** | **BOARD AUDIO PASS** | [PR25-11: успешное контрольное восстановление Golden](../../Examples/PR25-11-A2600-ORIGINAL-REBUILD/README.md) |
| **Brus-16 SFX**, включая Gerion, сторонние выпуски | [Papr1ka/brus16](https://github.com/Papr1ka/brus16), [релиз sfx](https://github.com/Papr1ka/brus16/releases/tag/sfx), [архив TP25K](https://github.com/Papr1ka/brus16/releases/download/sfx/tp25k.zip) | **BOARD VIDEO PASS** у всех оператором испытанных FS | **AUDIO NOT HEARD**, несмотря на объявленную поддержку звука | [Операторский отчёт Brus-16](../../ThirdParty/Brus16-SFX/README.md) |
| **PR25-08, 09, 10**, наши тесты интерфейса | [PR25-08](../../Examples/PR25-08-HDMI-AUDIO-GOLDEN/README.md), [сводка PR25-08..10](../../Examples/PR25-10-HDMI-AUDIO-PACKET-PROBE/RESULTS_RU.md) | **BOARD VIDEO PASS** — полосы и диагностические флаги | **AUDIO FAIL** — звук не услышан | Указанные аппаратные протоколы |
| **Sipeed SVO, Arcade MCR2**, отдельные сторонние FS | [Sipeed HDMI/SVO](https://github.com/sipeed/TangPrimer-25K-example/tree/main/hdmi/svo), [Arcade MCR2](https://github.com/alanswx/Arcade-MCR2-TangFPGA/tree/main/mcr2_primer25k) | **Именно в этих испытаниях изображения не получили** | Не подтверждено | [История этих испытаний](README.md) |

## Рабочий эталон: A2600Nano v2.5

- [Точная версия исходников A2600Nano (705bf787...)](https://github.com/MiSTle-Dev/A2600Nano/tree/705bf787675579721d339806cb522905dec73ed3).
- [Инструкция для Tang Primer 25K и PMOD](https://github.com/MiSTle-Dev/A2600Nano/blob/v2.5/TANG_PRIMER_25K.md).
- [Полный Gowin build_tp25k.tcl](https://github.com/MiSTle-Dev/A2600Nano/blob/v2.5/build_tp25k.tcl).
- [Видеотракт video.v](https://github.com/MiSTle-Dev/A2600Nano/blob/v2.5/src/misc/video.v), [HDMI и аудиопакеты hdmi.sv](https://github.com/MiSTle-Dev/A2600Nano/blob/v2.5/src/hdmi/hdmi.sv), PLL, serializer/OSER10 и согласованные ограничения составляют целую зависимую цепочку.
- Оригинальный Golden FS от автора: **SHA256 531b786061cc3b428d829e9f445787d20c6f847645031e3a0a57f64d58ba4aff**. Оператор подтвердил повторное появление изображения и звука при восстановлении Golden после неработающей пересборки PR25-11.

## PR25-13 — отозванный эксперимент

Первоначальное наблюдение от 15.11.2026 было записано как VIDEO+AUDIO PASS, однако при повторной загрузке точно идентифицированной локальной сборки 16–17.11.2026 экран остался без изображения. Воспроизводимый BOARD PASS отсутствует. Экспериментальная сборка и ошибочные паспорта «рабочей прошивки» удалены из текущей ветки; история Git сохраняет изменения. **Эталон — только оригинальная A2600Nano v2.5 Golden от автора**, а не пересборка Gowin 1.9.9.

## Правильный технический вывод

**Плата и PMOD DVI/HDMI ранее дали подтверждённое видео и звук на оригинальной A2600Nano v2.5 Golden.** Отсутствие SDRAM не помешало получению этих результатов.

**Не завершено:** обособление повторно используемого HDMI/audio IP, интеграция с собственным терминалом, UART, USB Host и PiKoSoL. Неудача изоляции компонентов не отменяет работающих образцов.

**Статус обновлён 15.11.2026:** эксперимент KonSol-DVI заработал без SDRAM и имеет **VIDEO BOARD PASS**; видеотерминал с UART и файловая система остаются следующими задачами.

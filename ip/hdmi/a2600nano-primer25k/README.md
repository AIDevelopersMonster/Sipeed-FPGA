# A2600Nano Tang Primer 25K — работающий HDMI + звук, эталонный IP-снимок

**BOARD PASS относится к оригинальной прошивке A2600Nano v2.5**: 14.11.2026 на нашей Tang Primer 25K с PMOD DVI фактически наблюдались **изображение и звук**. При этом **выделенный standalone IP ещё не собран и не испытан**; статус `IP BOARD PASS` пока не присваиваем. Работающие PiKoSoL не меняем.

## Происхождение и лицензия

Оригинал: [MiSTle-Dev/A2600Nano](https://github.com/MiSTle-Dev/A2600Nano), [релиз v2.5](https://github.com/MiSTle-Dev/A2600Nano/releases/tag/v2.5), tag commit `705bf787675579721d339806cb522905dec73ed3`.

Прямая ссылка на подтверждённую прошивку: [a2600nano_tp25k.fs](https://github.com/MiSTle-Dev/A2600Nano/releases/download/v2.5/a2600nano_tp25k.fs), 4 700 888 байт, SHA256 по данным релиза `531b786061cc3b428d829e9f445787d20c6f847645031e3a0a57f64d58ba4aff`.

Папка `vendor/` содержит **24 побайтово идентичных Git-blobs** (проверено совпадение SHA1 Git), включая `vendor/LICENSE`, исходники HDMI, видеопроцессинга, PLL, исходные `.cst`/`.sdc` и верхний уровень. Лицензия оригинала **GPL-3.0**; оставлены авторские заголовки и уведомления. Нельзя просто смешать этот RTL с иным публикуемым проектом без проверки условий GPL и лицензий компонентов.

## Состав IP и зависимостей

```text
vendor/
  LICENSE
  src/hdmi/*.sv                     HDMI packet encoder, ACR, infoframes,
                                    tmds_channel + Gowin OSER10 serializer
  src/misc/video.v                 исходная video/audio-связка
  src/misc/video_analyzer.v        синхронизация с внешним растром
  src/misc/scandoubler.v           удвоение строк и scanlines
  src/misc/osd_u8g2.v              экранное меню
  src/video_stabilize.sv           стабилизация видеосинхронизации
  src/tang/primer25k/
    gowin_pll_ntsc.ipc             исходная конфигурация PLL
    gowin_pll_ntsc.vhd             PLL_INIT и управление LOCK
    gowin_pll_ntsc_mod.vhd         Gowin-generated PLL
    pll_init.v                     процедура запуска PLL
    a2600_top_tp25k.cst           разводка платы
    a2600_top_tp25k.sdc           исходные временные ограничения
    a2600_top_tp25k.vhd           эталон включения (есть внешние зависимости)
  build_tp25k.tcl                  сценарий сборки ПОЛНОГО upstream проекта
```

**Важно:** это извлечённый **исходный эталон**, а не готовая автономная сборка. `a2600_top_tp25k.vhd` ссылается также на Atari CPU/TIA, SD, MCU, игровую ROM и другие файлы оригинального репозитория. Поэтому `vendor/build_tp25k.tcl` здесь без полного upstream не собирается. Для точного воспроизведения работающей прошивки клонируйте оригинал на теге `v2.5`.

## Архитектура проверенного HDMI

```text
50 MHz FPGA E2
  -> Gowin_PLL_ntsc / PLL_INIT / qualified LOCK
     -> 143.182 MHz clk_pixel_x5
     -> CLKDIV /5 -> 28.636 MHz пиксельный такт
  -> Atari video -> video_stabilize -> scandoubler -> OSD -> RGB
  -> Atari sound -> stereo volume -> ~48 kHz audio samples
  -> hdmi.sv -> HDMI ACR + audio/data-island packets
  -> tmds_channel x3 -> OSER10 x3
  -> ELVDS_OBUF x4 -> PMOD DVI -> монитор (видео + звук)
```

Разводка работающего оригинала (см. `vendor/src/tang/primer25k/a2600_top_tp25k.cst`):

| Пара | FPGA P/N | Сигнал |
|---|---|---|
| Clock | H5 / J5 | tmds_clk_p / tmds_clk_n |
| Data 0 | H8 / H7 | tmds_d_p[0] / tmds_d_n[0] |
| Data 1 | G7 / G8 | tmds_d_p[1] / tmds_d_n[1] |
| Data 2 | F5 / G5 | tmds_d_p[2] / tmds_d_n[2] |

**PMOD DVI подключён со стороны USB-A**, согласно оригинальным инструкциям. Внутреннего разъёма HDMI у Dock нет. В оригинале дифференциальные выходы создаются через `ELVDS_OBUF`, а не четырьмя обычными одиночными FPGA-выходами.

## Почему наш PR25-07 не дал изображения: различия, не доказанные причины

| | A2600 v2.5 — BOARD PASS | PR25-07 — только BUILD PASS |
|---|---|---|
| Физический TMDS | `OSER10`, `ELVDS_OBUF x4`, P/N-пары | `OSER10`, без `ELVDS_OBUF` |
| PLL и RESET | `PLL_INIT` и квалифицированный `LOCK` | прямой `PLLA`, raw LOCK |
| Частота пикселей | ~28.636 MHz | ~74.176 MHz |
| Режим | Atari 480p/576p | 720p |
| Аудио | HDMI, LPCM 48 kHz | DVI_OUTPUT=1, без аудио |
| UART | B3/C3 переиспользуются для BL616 JTAG/SPI | UART-терминал |

Все эти различия проверены в коде, но **нет контрольного эксперимента, однозначно определяющего причину** отсутствия изображения PR25-07. Точно известно только, что полный A2600 работает.

## Критерии дальнейшей проверки

1. Оригинальный `.fs` — сохранённый **GOLDEN BOARD PASS**. Никаких изменений Flash; использовать SRAM.
2. Для IP собрать *отдельный* минимальный проект цветовых полос со звуком, на базе PLL/OSER10/ELVDS_OBUF этого снимка. Не называть его PiKoSoL.
3. Проверить системные такты, reset, STA setup/hold и выходные TMDS-формы; затем проверить изображение и звук физически.
4. Только после этого изменить статус выделенного HDMI IP на **IP BOARD PASS**.

Подробности в [COMPARISON_RU.md](COMPARISON_RU.md), точное происхождение в [UPSTREAM_MANIFEST.json](UPSTREAM_MANIFEST.json). Авторская прошивка лежит в релизе upstream, не в этом IP-каталоге.

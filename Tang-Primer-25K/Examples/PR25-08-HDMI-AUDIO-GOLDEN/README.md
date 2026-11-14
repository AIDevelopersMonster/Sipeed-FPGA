# PR25-08 — минимальный HDMI + звук на Tang Primer 25K

**Независимый эксперимент:** вместо Atari — аппаратный генератор **8 цветовых полос и стереотона ~1 кГц**. Нет процессора, SDRAM, SD, внешней клавиатуры, ROM-образа, PiKoSoL и записи во Flash. Физический видеоразъём — **PMOD DVI со стороны USB-A**.

Основа: [эталонные исходники A2600Nano v2.5](../../../ip/hdmi/a2600nano-primer25k/README.md), побайтово сохранённые в `ip/hdmi/a2600nano-primer25k/vendor/`. Заимствуются **без изменений**: PLL/PLL_INIT, HDMI-пакетизатор, TMDS/OSER10. Два новых wrapper-модуля генерируют растр, RGB и звук и сохраняют выходы `ELVDS_OBUF`.

**Текущий статус (14.11.2026): BUILD PASS; BOARD WORKING — подтверждено оператором после SRAM-загрузки.** Gowin завершил сборку с EXIT 0 и создал `pr25_hdmi_audio.fs` размером **1 692 693 байт**, время **21:12:00**. После исправления синтаксиса `Program_SRAM.ps1` оператор подтвердил: **«Работает...»**. Видеотракт испытан на плате; наличие звука в этом коротком отчёте **отдельно не указано**. Timing setup/hold и повторный запуск/S2 ещё не подтверждены отдельными результатами. Исходная A2600Nano v2.5 ранее дала изображение и звук.

## Схема

```text
E2 50MHz --> Gowin_PLL_ntsc (PLL_INIT, qualified LOCK)
                     |
                     +--> 143.182MHz --> Gowin CLKDIV /5 --> 28.636MHz
                                                           |
                      +- synthetic 720x480 bars, 912x524 raster
                      +- stereo square wave ~1 kHz (nominal 48k samples/s)
                                                           |
                         unchanged upstream HDMI packetizer/TMDS
                                                           |
                                OSER10 x3 + ELVDS_OBUF x4
                                                           |
                              PMOD DVI (USB-A side) -> HDMI
```

Тайминги: 912 пикселей × 524 строки; видимая область 720×480; примерно 59,9 кадра/с; формат HDMI NTSC-like CEA VIC 2. На изображении ожидаются восемь полос с белой рамкой и белой горизонтальной линией. Звук — одинаковый низкоуровневый тестовый тон в двух каналах. S2/H11 сбрасывает генератор; PLL имеет собственную процедуру старта.

## Запуск в PowerShell 7

Сначала получить новый код из репозитория:

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin main
git restore --source FETCH_HEAD --worktree -- "ip/hdmi/a2600nano-primer25k" "Tang-Primer-25K/Examples/PR25-08-HDMI-AUDIO-GOLDEN"
```

Сборка **без программирования**:

```powershell
& .\Tang-Primer-25K\Examples\PR25-08-HDMI-AUDIO-GOLDEN\Build_HDMI_AUDIO.ps1
```

Только если **Gowin EXIT 0, `.fs` свежий, STA setup/hold приемлемы** — загрузить **лишь FPGA SRAM** (не Flash):

```powershell
& .\Tang-Primer-25K\Examples\PR25-08-HDMI-AUDIO-GOLDEN\Program_SRAM.ps1
```

Полученный файл: `Tang-Primer-25K/Examples/PR25-08-HDMI-AUDIO-GOLDEN/impl/pnr/pr25_hdmi_audio.fs`. Сценарий сборки пишет `evidence/PR25_08_BUILD_*.log`, фиксирует SHA256 и время файла. Отключать/перепрошивать Flash не требуется.

Если нет изображения, **сохраняем журналы и останавливаемся**, а не меняем PiKoSoL. Оригинальная рабочая `a2600nano_tp25k.fs` остаётся контрольным эталоном.

## Состав

- `rtl/pr25_hdmi_audio_top.vhd`: PLL v2.5, делитель CLKDIV/5 и независимый цветозвуковой модуль;
- `rtl/hdmi_audio_bars.sv`: синтезируемые счётчики координат, RGB-полосы, аудиосэмплы, оригинальный HDMI и дифференциальные выходы;
- `pins.cst`: H5/J5, H8/H7, G7/G8, F5/G5 — **пары P/N**, входной E2 и S2/H11;
- `timing.sdc`, `Build_HDMI_AUDIO.tcl`: минимальный Gowin GW5A-25A build;
- `Build_HDMI_AUDIO.ps1`, `Program_SRAM.ps1`: воспроизводимые операторские команды.

## Ограничения и возможный первый отказ

- Часть pinned PLL-модулей upstream была сгенерирована **Gowin 1.9.12**, а на компьютере установлена **1.9.9 Beta-4 Education**: несмотря на различие версий, наблюдался **Gowin EXIT 0 и сгенерированный .fs**. Показатели STA следует проверять по полному логу; совместимость всех вариантов PLL и режимов не утверждается.
- В режиме HDL используется **SystemVerilog 2017 / VHDL 2008**. Папку `vendor/` не редактировать.
- Источник GPL-3.0, новые wrappers также GPL-3.0-only; репозитории/условия указаны в [IP-справочнике](../../../ip/hdmi/a2600nano-primer25k/README.md).
- Автоматическая симуляция не представлена. **BUILD PASS** подтверждён выводом Gowin; аппаратный запуск подтверждён сообщением оператора «Работает...». Подробности аудио, STA и сброса не документированы отдельными проверками.

## Приёмка — данные 14.11.2026

| Проверка | Статус |
|---|---|
| Исходная прошивка A2600Nano v2.5 даёт HDMI + звук | **BOARD PASS — подтверждено оператором** |
| PR25-08 Gowin компиляция / PnR / генерация `.fs` | **BUILD PASS**, EXIT 0; `pr25_hdmi_audio.fs` 1 692 693 байт |
| PR25-08 STA setup/hold slack | **OPEN** — полный timing report в переписке не приведён |
| PR25-08 FPGA SRAM / аппаратный запуск | **BOARD WORKING — сообщение оператора** после запуска `Program_SRAM.ps1` |
| PR25-08 изображение | **BOARD WORKING** — результат сообщения «Работает...» |
| PR25-08 звук (~1 кГц) | **Уточнить отдельно** — аудиорезультат не расписан |
| PR25-08 повторная загрузка и кнопка S2 | **OPEN** |

Локальный лог сборки на компьютере оператора: `evidence/PR25_08_BUILD_20261114_211138.log`; не загружался в GitHub. Исправление PowerShell parser error сохранено в коммите `58c8b3f`. PiKoSoL, оригинальные RTL и `vendor/` не изменены.

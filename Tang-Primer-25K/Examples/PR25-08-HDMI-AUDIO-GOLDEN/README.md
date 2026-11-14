# PR25-08 — минимальный HDMI + звук на Tang Primer 25K

**Независимый эксперимент:** вместо Atari — аппаратный генератор **8 цветовых полос и стереотона ~1 кГц**. Нет процессора, SDRAM, SD, внешней клавиатуры, ROM-образа, PiKoSoL и записи во Flash. Физический видеоразъём — **PMOD DVI со стороны USB-A**.

Основа: [эталонные исходники A2600Nano v2.5](../../../ip/hdmi/a2600nano-primer25k/README.md), побайтово сохранённые в `ip/hdmi/a2600nano-primer25k/vendor/`. Заимствуются **без изменений**: PLL/PLL_INIT, HDMI-пакетизатор, TMDS/OSER10. Два новых wrapper-модуля генерируют растр, RGB и звук и сохраняют выходы `ELVDS_OBUF`.

**Текущий статус: SOURCE PREPARED / BUILD NOT RUN / BOARD NOT TESTED.** ПОЛНЫЙ оригинальный A2600Nano v2.5 получил наблюдаемый BOARD PASS (картинка и звук) 14 ноября 2026 г. Этот новый проект **ещё не подтвердил** сборку и работоспособность.

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

- Часть pinned PLL-модулей upstream была сгенерирована **Gowin 1.9.12**, а на компьютере установлена **1.9.9 Beta-4 Education**: синтез совместимости пока не подтверждён. При ошибке сохраняем точный diagnostic log, не подменяем PLL другой реализацией без изолированного сравнения.
- В режиме HDL используется **SystemVerilog 2017 / VHDL 2008**. Папку `vendor/` не редактировать.
- Источник GPL-3.0, новые wrappers также GPL-3.0-only; репозитории/условия указаны в [IP-справочнике](../../../ip/hdmi/a2600nano-primer25k/README.md).
- Отдельных автоматических симуляций и аппаратного запуска на Windows не проводилось. **BUILD PASS или BOARD PASS не утверждаем до логов.**

## Приёмка (открыта)

| Проверка | Статус |
|---|---|
| Исходная прошивка A2600Nano v2.5 даёт HDMI + звук | **BOARD PASS — подтверждено оператором** |
| PR25-08 Gowin компиляция / PnR / STA | OPEN |
| PR25-08 FPGA SRAM programming | OPEN |
| PR25-08 изображение цветных полос | OPEN |
| PR25-08 звук | OPEN |
| PR25-08 повторный запуск / S2 | OPEN |

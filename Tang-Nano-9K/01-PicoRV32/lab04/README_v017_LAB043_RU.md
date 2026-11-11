# PiKoSoL LAB-04.3 v0.1.7 — программируемая графика + ASCII-псевдографика

**Статус пакета:** кандидат RTL. Python-модель и статические тесты можно запускать
без FPGA. Icarus RTL, Gowin PnR, STA и аппаратные результаты требуют запуска
на Windows пользователя. Наличие `.fs` НЕ достаточно для разрешения SRAM.

## Цель

В работающий тракт LAB-04.2 `UART -> PicoRV32 -> MMIO -> CDC -> HDMI`
добавлены два независимых программируемых прямоугольника A и B и
общая **псевдографическая ASCII-панель**. Панель печатается **самим CPU**
на UART TX и зеркалируется существующим пассивным UART SVO HDMI терминалом;
отдельную псевдографику в Windows создавать не нужно.

## Архитектура

```
 PC UART RX 115200
        |
        v
    PicoRV32 (27 MHz) ----> LED MMIO ---> LED1..LED6
        |                   |-> LED CDC ---> LED HUD
        |
        +--> VIDEO MMIO 0x20000100..13C
        |       |
        |       +--> 28-bit command CDC --> pixel stage A/B
        |                                    | frame COMMIT / SOF
        |                                    v
        |                                 graphics overlay
        +--> UART TX --> passive SVO terminal ASCII tap

 SVO test card --> graphics --> text overlay --> LED HUD --> encoder/TMDS
                      ^             ^
                   object A/B    CPU ASCII pseudo-panel
```

`lab04_video_clocks.v`, PLL/CLKDIV, OSER10 lane-reset registers, PHY, pinouts,
original LED HUD and HDMI Smoke are unchanged. No framebuffer, PSRAM or DMA.
The two rectangles are generated as combinational pixels at 640x480V.

### MMIO ABI (32-bit aligned stores, low 24 bits used)

| Address | Object A | Object B | Semantics |
| --- | --- | --- | --- |
| 0x20000100 / 0x20000120 | X | X | [9:0] 0..1023 |
| 0x20000104 / 0x20000124 | Y | Y | [9:0] 0..1023 |
| 0x20000108 / 0x20000128 | W | W | [7:0] 0..255 |
| 0x2000010C / 0x2000012C | H | H | [7:0] 0..255 |
| 0x20000110 / 0x20000130 | BGR | BGR | [23:0] 0xBBGGRR (not RGB byte order) |
| 0x20000114 / 0x20000134 | CTRL | CTRL | bit0 enable, bit1 outline-only, bit2 checker |
| **0x2000013C** | **COMMIT** | — | store any word to request frame-atomic update |

Reads return the **CPU-side shadow**, not pixel-frame readback. MMIO full-word
writes stall PicoRV32 until a previous command is acknowledged by the pixel
clock-domain mailbox, so commands are neither dropped nor reordered. The
`COMMIT` event is carried through the same mailbox and applied at accepted
start of frame (SOF). Uncommitted stage changes are invisible. Intermediate
COMMIT states may appear if the program commits each change on separate frames.

### Встроенная клавиатура UART (один ASCII-байт на команду)

| Команды | Действие |
| --- | --- |
| `0`–`6` | прежнее количество LED, без изменения протокола |
| `a`–`f` | прежний одиночный LED, без изменения протокола |
| `?` | ответ `M=XX` от LED MMIO |
| `A`, `B` | выбрать графический объект A или B (**регистр важен**) |
| `i`, `j`, `k`, `l` | вверх, влево, вниз, вправо на 8 пикселей |
| `R`, `G`, `U`, `W` | красный, зелёный, синий, белый (`U` = blUe) |
| `X`, `O`, `K` | toggle enable / outline / checker fill |
| `+`, `-` | ширина объекта +8 / -8 |
| `p` | псевдографика CPU -> UART и HDMI, печатается с текущими LED и параметрами |

В ответ на видеокоманды CPU возвращает `V` и приглашение `> `.
Координаты X/Y обновляются по модулю 1024, размеры по модулю 256;
при достижении границ объект может выйти за активную область — это
**ограничение лабораторного прототипа**, а не аппаратный дефект.

### ASCII-псевдографика с одной командой `p`

Пример после `3p`:

```
+---------------------+
| PiKoSoL 640x480     |
| LED [###...]        |
| OBJ=A X=0A0         |
| Y=10E W=60          |
+---------------------+
> 
```

ASCII-символы `+ - | # .` одинаковы на Windows COM-терминале и в `svo_term`.
Это не ANSI-терминал: SVO-референс не интерпретирует Escape/CSI; не выдаём
ложный вывод об ANSI, цветном тексте или Unicode box-drawing на HDMI.
Графика A/B рисуется аппаратной видеологикой **под** текстом `svo_term`;
ASCII панели CPU UART TX остаётся читаемым. LED HUD — самый верхний слой.

## Безопасный порядок запуска

Из `C:\GitHub\Sipeed-FPGA`, после предварительного SHA-проверенного применения патча:

```powershell
$env:PATH = 'C:\msys64\ucrt64\bin;' + $env:PATH
python .\01-PicoRV32\lab04\tools\verify_kit.py
& .\01-PicoRV32\lab04\tools\test_lab04.ps1 -ModelOnly
& .\01-PicoRV32\lab04\tools\test_lab04.ps1
& .\01-PicoRV32\lab04\tools\build_lab04.ps1 -Mode CPU
```

Пришлите вывод и архив STA следующего прогона, **не программируя SRAM**:

```powershell
$Lab = 'C:\GitHub\Sipeed-FPGA\01-PicoRV32\lab04'
$Job = Get-ChildItem "$Lab\build" -Directory -Filter 'cpu_*' |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
$Report = Join-Path $Job 'work\impl\pnr\picorv32_lab04_hdmi_nano9k_tr_content.html'
$Log = Join-Path $Job 'gowin_cli.log'
python "$Lab\tools\check_sta_v017.py" $Report --log $Log
```

**Только предварительный STA:** `check_sta_v017.py` проверяет наличие/активность
15 constraints, отсутствие негативного slack и наличие хотя бы одного пути для
каждой wildcard-группы. Он **НЕ доказывает полное покрытие 28 разрядов** нового
CDC. До одобрения независимого просмотра Gowin exception-path отчёта новый `.fs`
на FPGA **не загружать**. Если обнаружены ошибки `TA1124`, PnR или setup,
не решать их глобальным `set_false_path` или игнорированием.

После независимого подтверждения PnR/STA/CDC и программирования **только SRAM**:

```powershell
& .\01-PicoRV32\lab04\tools\test_lab04_v017_board.ps1 -PortName COM10
python .\01-PicoRV32\lab04\tools\console_lab04.py --port COM10
```

Выбирайте только один процесс, открывающий COM10, одновременно.
Python interactive console requires `python -m pip install pyserial`.
`test_lab04_v017_board.ps1` does not write Flash and pauses for manual HDMI
checks. `-NoVisualPrompts` tests serial only; NEVER count it as HDMI proof.

## Отдельные статусы / non-claims

- v0.1.6a STA & physical HDMI, UART, LED OSD previously PASS (known baseline).
- v0.1.7 Python ROM model: check locally. Icarus new mailbox/graphics RTL:
  independent testbench added, user Windows run still pending.
- v0.1.7 Gowin synthesis/PnR/STA, 28-bit CDC path coverage, physical HDMI:
  **PENDING**. Do not claim the v0.1.6a +0.978ns setup slack transfers to v0.1.7.
- No framebuffer, GPU, VGA text-mode buffer, console ANSI/VT100 or DMA claims.

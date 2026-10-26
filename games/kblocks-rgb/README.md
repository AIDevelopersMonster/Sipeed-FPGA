# KonSol RetroStation — RS-004 K-BLOCKS RGB v0.1.0

**STATUS: SOURCE CANDIDATE. NOT SIM PASS / NOT GOWIN FIT PASS / NOT BOARD PASS / NOT RELEASED.**

Standalone original falling-block puzzle for **Sipeed Tang Nano 9K (GW1NR-9C)**. The RTL implements gameplay directly in Verilog, without PicoRV32, emulation, SD, external RAM or a framebuffer. It reuses the verified PiKoSoL HDMI/UART/video-clock infrastructure without touching PONG or BREAKOUT.

## RU — что реализовано в исходниках

- Экран HDMI **640×480**, логика пикселей и игры в едином домене **25,2 МГц**.
- Поле **10×20** (по 16×16 экранных пикселей на клетку).
- Семь фигур по четыре клетки; четыре положения поворота, корректная проверка занятости и границ.
- Падение с замедлением/ускорением, горизонтальное перемещение с автоповтором.
- Постановка фигуры в поле; **очистка нескольких соседних заполненных линий** с корректным сдвигом.
- Десятичный счётчик линий 00–99, **NEXT**-превью, 4 палитры, READY / PLAY / GAME OVER и перезапуск.
- Порядок фигур **предсказуемый** (I → O → T → L → J → S → Z); сознательно без PRNG или 7-bag в v0.1.0.
- **Без wall-kick и hard drop**. Не является эмуляцией Tetris и не использует коммерческие ROM/изображения/музыку.

## Управление / Controls

Windows PowerShell 7, FT2232 channel B serial, **115200 8N1**:

| Клавиша | Action |
| --- | --- |
| Left / A | Сдвиг влево (удержание) |
| Right / D | Сдвиг вправо (удержание) |
| Down / S | Ускоренное падение (удержание) |
| Up / W | Поворот по часовой стрелке (по нажатию) |
| P / Space / Enter | Старт, новая игра после Game Over |
| R | Полный сброс до READY |
| 1–4 | Цветовые палитры |
| Q / Esc | Выход из PowerShell контроллера |

CLI controller from **Sipeed-FPGA repository root**:

```powershell
.\games\kblocks-rgb\tools\control_kblocks.ps1 -PortName COM10
```

Replace **COM10** with the actual FPGA USB-UART channel B port. The script never touches JTAG, Flash, or reset control lines.

## Воспроизводимая проверка и сборка / CLI

On operator's Windows host with Icarus Verilog and Gowin V1.9.9 Beta-4 Education (or compatible):

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
.\01-PicoRV32\lab04\tools\fetch_picotiny.ps1
.\games\kblocks-rgb\test.ps1
.\games\kblocks-rgb\build.ps1
```

- **Testbench:** 28 shape orientations (4 cells each), wall/floor collision, start, movement, rotation, accelerated gravity, lock, **two adjacent lines**, single line + row shift, top-out, restart and stream handshake.
- **Build:** copies pinned SVO sources with SHA-256 manifest validation into a timestamped isolated directory; runs `gw_sh.exe` in a separate workdir; prints bitstream location and SHA-256. Does NOT program the FPGA.
- **Expected console marker after actual simulator success:** `RS004_KBLOCKS_TB_PASS`. This marker has **not been observed in this authoring environment**.
- Save the **full PnR + STA report**, with all clock constraints, unconstrained-path checks and positive setup/hold/recovery/removal for **exact built candidate**. A checksum from any older game is not applicable.
- No `.fs` is committed into the source tree or advertised for browser loading until Gowin/PnR and physical tests succeed.

### Only after SIM + FIT + STA acceptance — 3 board tests

1. **JTAG SRAM + HDMI:** load the exact SHA-256-identified candidate using the existing SRAM-only programmer on Tang Nano 9K; no Flash operations. Confirm field, next-piece preview, selected palette, raster stability.
2. **Controls + line clearing:** connect UART 115200 8N1; check left/right, rotation, soft drop and at least one full line removal. Check the line counter and the next figure.
3. **Top-out + restart:** fill the top to trigger game over; restart. Record test/board/date/COM, source commit, `.fs` SHA-256 and screenshots or short video if possible.

**Stop rule:** do 2–3 documented focused board checks. If a problem survives, inspect power/USB FT2232/COM, HDMI, constraints/clock/STA before changing working firmware. Keep board bring-up within 1–2 days, no repair of inexpensive boards.

## EN summary

**RS-004 K-BLOCKS** is a *source candidate*, not a released hardware product. The 10×20 native Verilog gameplay grid implements seven four-cell shapes, four orientations, movement, soft drop, locking, complete-row compaction, next-piece preview, decimal cleared-line counter, game over and restart. HDMI 640×480 and UART 115200 reuse the **existing hardware-validated** video path. The game itself still needs the Icarus test PASS, Gowin FIT/full STA and operator physical verification.

### License / boundaries

Original game logic and integration: MIT, subject to repository LICENSE. Third-party SimpleVOut remains ISC; Gowin IP and tool redistribution are governed separately. No commercial game title, logo, graphic asset, sound or ROM is reproduced. The original gameplay is a generic falling-block mechanic.

[KonSol RetroStation programme](https://github.com/AIDevelopersMonster/KonSol-RetroStation) · [RS-004 plan](https://github.com/AIDevelopersMonster/KonSol-RetroStation/blob/main/docs/FPGA_9K_GAMES_NEXT.md)

# KonSol RetroStation RS-003 — BREAKOUT RGB v0.1.0

**Operator-reported BOARD PASS, 26 October 2026:** BREAKOUT RGB was programmed into a real **Sipeed Tang Nano 9K (GW1NR-9C)** and the operator successfully **completed and won the game** using the PowerShell keyboard controller. This is reported board evidence, not independent automated hardware certification.

The game is independently authored Verilog without PicoRV32 CPU, SD/ROM, OS, or framebuffer. It uses the existing PiKoSoL LAB-04 640×480 HDMI and 115200 8N1 UART interfaces, without modifying Pong.

## Features / Возможности

- 8 columns × 4 rows = 32 destructible bricks; ball and paddle with directional bouncing.
- Three lives, start/restart, win/loss, four palettes.
- GPIO-free control via onboard FT2232 USB-UART channel B.
- 640×480 HDMI, 25.2 MHz pixel clock and 126 MHz HDMI serializer clock.

## Keyboard / Клавиатура

Use `games/breakout-rgb/tools/control_breakout.ps1` on Windows PowerShell 7, with the actual serial COM port:

```powershell
.\games\breakout-rgb\tools\control_breakout.ps1 -PortName COM10
```

| Key | Action |
| --- | --- |
| Left arrow / A | Paddle left |
| Right arrow / D | Paddle right |
| P / Space / Enter | Launch ball |
| R | Restart |
| 1–4 | Palette |
| Q / Esc | Close controller; release held keys |

The Pong web controller is not an equivalent keyboard (Breakout requires its own Launch input).

## Build and test / Сборка

```powershell
.\01-PicoRV32\lab04\tools\fetch_picotiny.ps1
.\games\breakout-rgb\test.ps1
.\games\breakout-rgb\build.ps1
```

Requires Gowin EDA V1.9.9 Beta-4 Education or a compatible version, plus Icarus Verilog for simulation. The build script validates pinned vendor SVO sources and outputs an isolated candidate `.fs` and its SHA-256. A newly rebuilt file is **not** automatically equivalent to the hardware-tested build.

## Confirmed build identity / Бинарный файл

- Local run: `games/breakout-rgb/build/20261026_093802/work/impl/pnr/`.
- File: `pikosol_breakout_rgb_nano9k.fs`.
- Tested candidate SHA-256: `4CF80DBD008B0D41D4316BF63DB952190C03940A4FFB1FFC00CAB09210AE8789`.
- Logic 1612/8640 (19%), registers 510/6693 (8%), BSRAM 0%.
- Operator report: smoke simulation PASS, Gowin PnR build PASS, Setup/Hold summary 0 violations, positive extracted 25-path minima: Setup +6.035 ns, Hold +0.550 ns, Recovery +0.232 ns, Removal +0.870 ns.
- Physical operator observation: live HDMI gameplay, functional controls, completed winning round.

Proof: [operator timing report](acceptance/RS003_STA_2026-10-26.md) and [operator hardware receipt](acceptance/RS003_BOARD_2026-10-26.md). Timing claims are limited to the excerpted report; no full unconstrained-path certification is implied.

## Program the FPGA / Программирование

**Gowin Programmer (CLI, volatile SRAM only):**

```powershell
.\01-PicoRV32\lab04\tools\program_lab04_sram.ps1 -Bitstream "C:\GitHub\Sipeed-FPGA-BREAKOUT\games\breakout-rgb\build\20261026_093802\work\impl\pnr\pikosol_breakout_rgb_nano9k.fs" -Program
```

**PiKoSoL WebUSB Loader (Chrome/Edge, also volatile SRAM):**

Open https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-loader/ → choose **KonSol BREAKOUT RGB v0.1.0** → select the exact **local `.fs`** → inspect `SHA-256 PASS` → connect FT2232 channel A **JTAG Debugger** → program to **SRAM only** → check HDMI. The Breakout profile enforces the exact hash of the tested binary. **Auto-download is not available until the exact .fs is separately published to the corresponding GitHub Pages path.**

### Release status / Релиз

Game sources and instructions are published on GitHub. To publish the **tested binary** with the same hash, run the local PowerShell [release upload script](publish_release.ps1) after the source is on `main` and the Gowin/IP binary redistribution terms are checked:

```powershell
.\games\breakout-rgb\publish_release.ps1 -Bitstream "C:\GitHub\Sipeed-FPGA-BREAKOUT\games\breakout-rgb\build\20261026_093802\work\impl\pnr\pikosol_breakout_rgb_nano9k.fs" -Publish
```

The script will **refuse** a wrong SHA, will not overwrite an existing release, will create a public prerelease asset and SHA256SUMS, and will re-download the uploaded binary to verify its exact hash. The initial release URL is https://github.com/AIDevelopersMonster/Sipeed-FPGA/releases/tag/konsol-breakout-rgb-v0.1.0 (valid **only after** the upload succeeds).

## Limitations and licenses

The game is a simple v0.1.0 arcade demonstrator, not a physical-accuracy simulator. It has no numeric score overlay or audio. Original game RTL under the main repository MIT LICENSE; SimpleVOut is ISC (Clifford Wolf); Gowin EDA and device IP use separate vendor terms. No commercial game ROM or third-party game code is bundled.

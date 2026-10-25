# PiKoSoL Pong RGB — Tang Nano 9K (UNTESTED CANDIDATE)

An independently built color HDMI Pong game for Tang Nano 9K (GW1NR-9C). The gameplay and UART keyboard controller are original RTL; Sipeed/Clifford Wolf SVO video modules and Gowin IP remain external **unchanged**, fetched through the existing LAB-04 pinned source mechanism. **No game ROM, CPU, SD card, or external controller required.** No changes to PiKoSoL v0.2.0, SD-08, WebUSB, or the main branch.

## Connect and play

1. Windows 10/11, PowerShell 7, existing LAB-04 Gowin CLI and SVO vendor sources. Run `./games/pong-rgb/build.ps1` from PowerShell and review the Gowin post-route STA results. If timing is invalid, **do not load the image**.
2. After a clean build and timing acceptance, use the *existing* [PiKoSoL WebUSB SRAM loader](../../docs/lab04/web-loader/) and select the generated local `.fs`. **SRAM only; never use Flash**. There is no prebuilt release yet.
3. On HDMI, the game should show left and right paddles, a ball, center line, two digits and a dark colored field.
4. Open [Pong keyboard controller](web/index.html) on a secure origin, e.g. GitHub Pages after publishing the branch, in Chrome/Edge; connect the **USB Serial Port (COMx), FT2232 interface B** at 115200 8N1. Only one program may own COM.
5. Player 1: **W/S**. Player 2: **I/K** when AI is disabled. **A** toggles AI. **R** restarts. **1–4** select palettes. Browser sends key-down and key-up byte pairs. Blurring the window or disconnecting sends a release-all command.

## Simple serial protocol

| ASCII byte | Effect |
|---|---|
| `w`, `s`, `i`, `k` | corresponding key pressed |
| `W`, `S`, `I`, `K` | corresponding key released |
| `x` | release all moving keys |
| `a` | toggle right-hand AI |
| `r` | reset score/positions |
| `1`, `2`, `3`, `4` | Neon / Retro / Matrix / Sunset |

UART RX is the already existing `01-PicoRV32/rtl/uart_rx_8n1.v`, clocked at 25.2 MHz so the entire keyboard-to-pixel path is in one domain. The rest of the same hardware pinout as LAB-04 is used (UART RX pin 18, HDMI pairs). No UART TX or separate in-game terminal: the browser **is** the keyboard terminal.

**Test status:** RTL has been reviewed structurally; Gowin synthesis, physical HDMI and keyboard response have **not** yet been executed. Stop after a few documented board tests; prefer diagnosing COM device selection and pin mapping over repeated firmware rewrites.

## Provenance and licenses

- New `pong_uart_hdmi_top.v`, `pong_rgb_core.v`, build and browser controls: Copyright (c) 2026 AIDevelopersMonster, **MIT** (root LICENSE). Gameplay and pixel renderer are authored here, not copied from a commercial game or arcade ROM.
- Existing `01-PicoRV32/rtl/uart_rx_8n1.v`, `lab04_video_clocks.v`: existing repository **MIT**, unchanged.
- SVO / Simple Video Out, Clifford Wolf (2014): permissive text requiring preservation of upstream notices; **do not remove upstream notices or relicense the SVO source**. Source is fetched at pinned revision `c3b795799f23de91982be52db4273a8eea100cdb` using LAB-04's existing process.
- Gowin PLL/CLKDIV/OSER10/ELVDS primitives are device/vendor IP and not covered by the project's MIT grant.
- External comparisons (not code dependencies): [YanLiu-t Pong MIT](https://github.com/YanLiu-t/tang-nano-fpga-boards), [MatthewKing2 FPGA-Pong MIT](https://github.com/MatthewKing2/FPGA-Pong).

The finished compiled image can only be offered after a successful real-board demonstration and review of the corresponding distribution rights/notice requirements.

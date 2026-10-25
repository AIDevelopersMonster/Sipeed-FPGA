# PiKoSoL Pong RGB v1.2 — Tang Nano 9K (gameplay fix candidate)

An independently built color HDMI Pong game for Tang Nano 9K (GW1NR-9C). The gameplay and UART keyboard controller are original RTL; Sipeed/Clifford Wolf SVO video modules and Gowin IP remain external **unchanged**, fetched through the existing LAB-04 pinned source mechanism. **No game ROM, CPU, SD card, or external controller required.** No changes to PiKoSoL v0.2.0, SD-08, WebUSB, or the main branch. Hardware validation of the original game is documented by the operator (25 October 2026), The v1.1 image has been built and physically tried, revealing repetitive fixed-angle ball motion. The v1.2 gameplay change still requires rebuild, STA and physical validation.

## Connect and play

1. Windows 10/11, PowerShell 7, existing LAB-04 Gowin CLI and SVO vendor sources. Run `./games/pong-rgb/build.ps1` from PowerShell and review the Gowin post-route STA results. If timing is invalid, **do not load the image**.
2. After a clean build and timing acceptance, use the *existing* [PiKoSoL WebUSB SRAM loader](../../docs/lab04/web-loader/) and select the generated local `.fs`. **SRAM only; never use Flash**. Keep the previously tested v1.0/v1.1 files. v1.2 is source-only until new build and STA; do not reuse earlier hashes.
3. On HDMI, the game should show left and right paddles, a ball, center line, two digits and a dark colored field.
4. Open [Pong keyboard controller](web/index.html) on a secure origin, e.g. GitHub Pages after publishing the branch, in Chrome/Edge; connect the **USB Serial Port (COMx), FT2232 interface B** at 115200 8N1. Only one program may own COM.
5. Player 1: **W/S**. Player 2: **I/K** when AI is disabled. **A** toggles AI. **R** restarts. **1–4** select palettes. **5–7** set AI Easy / Normal / Hard (default Normal). First to 9 wins: game freezes, the winner's score and paddle blink, and R starts a fresh match. Browser sends key-down and key-up byte pairs. Blurring the window or disconnecting sends a release-all command.

## Simple serial protocol

| ASCII byte | Effect |
|---|---|
| `w`, `s`, `i`, `k` | corresponding key pressed |
| `W`, `S`, `I`, `K` | corresponding key released |
| `x` | release all moving keys |
| `a` | toggle right-hand AI |
| `r` | reset score/positions |
| `1`, `2`, `3`, `4` | Neon / Retro / Matrix / Sunset |
| `5`, `6`, `7` | Easy / Normal / Hard (AI paddle moves 1/2/4 pixels per frame and begins reacting at X=505/415/350 respectively) |

UART RX is the already existing `01-PicoRV32/rtl/uart_rx_8n1.v`, clocked at 25.2 MHz so the entire keyboard-to-pixel path is in one domain. The rest of the same hardware pinout as LAB-04 is used (UART RX pin 18, HDMI pairs). No UART TX or separate in-game terminal: the browser **is** the keyboard terminal.

**Test status:** User confirmed v1.0 on physical Tang Nano 9K: HDMI image, UART keyboard, paddle control, collisions, scoring, restart and no observed lockups. The v1.0 score wrapped 9 to 0 and AI was too strong. v1.1 physically revealed a repetitive trajectory because only the X direction reversed on paddle hits. v1.2 introduces paddle-contact-dependent vertical speed/direction, non-identical serves based on an 8-bit LFSR, and three visibly distinct AI movement/reaction settings. The AI setting is shown as a large digit 1, 2, or 3 near the upper-right. v1.2 has NOT passed Gowin STA or hardware testing. Do not publish as hardware-verified v1.1 until accepted. Acceptance: (1) first to 9, blink and R reset for either side, (2) test AI 5/6/7 and manual P2, (3) ensure HDMI/UART and palettes remain stable; review STA. Stop after these three board tests rather than refactoring stable video logic.

## Provenance and licenses

- New `pong_uart_hdmi_top.v`, `pong_rgb_core.v`, build and browser controls: Copyright (c) 2026 AIDevelopersMonster, **MIT** (root LICENSE). Gameplay and pixel renderer are authored here, not copied from a commercial game or arcade ROM.
- Existing `01-PicoRV32/rtl/uart_rx_8n1.v`, `lab04_video_clocks.v`: existing repository **MIT**, unchanged.
- SVO / Simple Video Out, Clifford Wolf (2014): permissive text requiring preservation of upstream notices; **do not remove upstream notices or relicense the SVO source**. Source is fetched at pinned revision `c3b795799f23de91982be52db4273a8eea100cdb` using LAB-04's existing process.
- Gowin PLL/CLKDIV/OSER10/ELVDS primitives are device/vendor IP and not covered by the project's MIT grant.
- External comparisons (not code dependencies): [YanLiu-t Pong MIT](https://github.com/YanLiu-t/tang-nano-fpga-boards), [MatthewKing2 FPGA-Pong MIT](https://github.com/MatthewKing2/FPGA-Pong).

The finished compiled image can only be offered after a successful real-board demonstration and review of the corresponding distribution rights/notice requirements.

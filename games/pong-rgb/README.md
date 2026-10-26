# PiKoSoL PONG RGB v1.2 — HDMI Pong on Tang Nano 9K

**Operator-reported BOARD PASS, 26 October 2026 · Open-source RTL and Web Serial keyboard · SRAM-only FPGA image.**

A playable, independently authored color Pong for **Sipeed Tang Nano 9K (GW1NR-9C)**. The game logic and pixels are implemented directly in Verilog; **PicoRV32, ROM images, SD card and an external game controller are not required**. HDMI signaling reuses the pinned LAB-04 SimpleVOut components, and keyboard input reuses the existing UART receiver.

**Start:** [Pong keyboard on GitHub Pages](https://aidevelopersmonster.github.io/Sipeed-FPGA/pong-rgb/) · [WebUSB SRAM loader](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-loader/) · [Third-party notices](THIRD_PARTY_NOTICES.md)

## Board test and limits / Проверка на плате

- On **26 October 2026**, the operator confirmed that the latest Pong game works on physical Tang Nano 9K and supplied a photo of the running HDMI game (visible match score **7:2** and difficulty indicator). This is **operator evidence**, not an independent automated hardware certification.
- Previous board tests found a repetitive ball trajectory in v1.1. v1.2 contains contact-height-dependent ricochets, varied serves and selectable AI difficulty.
- The reported **v1.2 local-build candidate** is `pikosol_pong_rgb_nano9k.fs`, output from `20261025_215247`, SHA-256:

  ```text
  978D9BCFF7C1EF1350F88AF2C603A00B7D3BB6325EA39019CA57CF5091639F96
  ```

- A prior v1.2 timing report showed **zero setup and hold violations**, but it referred to a **different bitstream hash**. Do **not** transfer STA conclusions across builds. The post-route STA report bound to the exact hash above is **not included in this repository**, and the operator's photograph does not independently prove a binary hash.
- **The Pong `.fs` is not currently hosted on GitHub.** Source code and browser keyboard **are published**; the WebUSB loader permits local `.fs` selection with SHA-256 verification. Do not advertise a GitHub binary download until the exact file is uploaded, its distribution terms checked and its hash published.

## Quick start / Как запустить

1. Prepare a **Tang Nano 9K**, an HDMI monitor, a Windows 10/11 PC with PowerShell 7, Gowin CLI and the pinned LAB-04 video sources.
2. From the repository root, prepare pinned video sources (if not already installed), then build:

   ```powershell
   .\01-PicoRV32\lab04\tools\fetch_picotiny.ps1
   .\games\pong-rgb\build.ps1
   ```

   The build script checks the pinned SVO sources and prints the candidate `.fs` path and its **own** SHA-256. Inspect the **post-route STA**; do not flash any bitstream with timing failures.
3. Open the [PiKoSoL WebUSB Loader](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-loader/). Select the **PONG RGB v1.2** profile and choose a **local** `.fs` file. If the local file is the pinned operator build above, confirm that its SHA matches. Program **SRAM only**, via FT2232 JTAG channel A; **do not write the configuration Flash**.
4. Check HDMI. Open the [Web Serial Pong keyboard](https://aidevelopersmonster.github.io/Sipeed-FPGA/pong-rgb/) in Chrome/Edge on HTTPS. Connect to **FT2232 USB Serial (channel B)** at **115200 8N1**, then click the game-control panel to give it keyboard focus.

Selecting a different `.fs` fully replaces the **volatile FPGA configuration**. Pong is **an alternative FPGA image**, **not** firmware that runs inside the existing PiKoSoL RISC-V CPU.

## Controls

| Key | Action |
| --- | --- |
| **W / S** | Player 1 paddle up/down |
| **I / K** | Player 2 paddle up/down (AI disabled) |
| **A** | Enable/disable right-hand AI |
| **1–4** | Color palettes: Neon / Retro / Matrix / Sunset |
| **5 / 6 / 7** | AI Easy / Normal / Hard |
| **R** | Restart match |

The match ends at **9 points**; the winner and score blink. A large **1, 2 or 3** on the right of HDMI indicates the active AI difficulty. The browser sends lowercase ASCII for movement key-down, uppercase for key-up, and `x` to release all keys on focus loss.

## Reproducing the build / Воспроизводимость

- Sources: `rtl/pong_rgb_core.v`, `rtl/pong_uart_hdmi_top.v`.
- Pin constraints: `constraints/pong_rgb.cst`, `constraints/pong_rgb.sdc`.
- Reproducible build entry point: `build.ps1`, `build.tcl`. Requires a local Gowin EDA installation; the vendor tool is **not** redistributed.
- Browser keyboard source: `web/index.html`; deployed GitHub Pages copy: `docs/pong-rgb/index.html`.
- SVO sources are fetched at pinned commit `c3b795799f23de91982be52db4273a8eea100cdb`, not copied into this project's source directory.
- The game uses **one 25.2 MHz pixel clock domain** for gameplay and synchronized UART receive. HDMI serialization uses the previously developed LAB-04 video clocking scheme.

## Licensing

Original project files: **MIT**, see [repository LICENSE](../../LICENSE). SimpleVOut (Clifford Wolf) remains under **ISC**, retaining upstream copyright notices; Gowin IP and tools remain under vendor terms. The independent gameplay implementation does **not** incorporate an arcade ROM or upstream `svo_pong.v`. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Before publicly distributing a compiled `.fs`, check the Gowin tool/IP distribution terms for the installed version, record its exact SHA-256, and attach the matching STA and acceptance evidence.

---

**Русское резюме.** Аппаратный Pong v1.2 на Tang Nano 9K оператор подтвердил 26.10.2026. Исходники игры, инструкции сборки и браузерное управление опубликованы. Движок игры — Verilog без процессора PicoRV32; интерфейс HDMI и ввод с клавиатуры работают через FPGA и UART. Для загрузки пока нужен **локальный `.fs`**: публичного бинарного файла Pong ещё нет. Запись допускается только в SRAM.
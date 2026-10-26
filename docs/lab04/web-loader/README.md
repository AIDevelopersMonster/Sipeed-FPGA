# LAB-04.4 — PiKoSoL WebUSB Loader (hardware-verified)

**Goal:** load PiKoSoL v0.2.0 Gowin `.fs` to Tang Nano 9K **SRAM** directly from the first-party GitHub Pages screen (not an iframe or redirect to a third-party programming site).

**Status:** HARDWARE PASS (operator-verified on Windows 11 / CHUWI N100 / Tang Nano 9K, 23 October 2026). Initial CDN import failure was repaired. The user subsequently confirmed programming with the first-party WebUSB Loader and confirmed automatic `.fs` retrieval after the GitHub Pages same-origin fix. See [acceptance record](../LAB044_ACCEPTANCE_2026-10-23_RU.md).

## URL

`https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-loader/`

## Program

1. Open the above URL in Chrome or Edge over HTTPS; `WebUSB` and `crossOriginIsolated` should both read READY. Service-worker activation might require one automatic reload.
2. Use the **Get from GitHub** button to fetch official `.fs`. The button now retrieves the verified image from the **same GitHub Pages origin**, avoiding the original GitHub Releases CORS issue. If that is unavailable, manually download `picorv32_lab04_hdmi_nano9k.fs` from the v0.2.0 GitHub Release, then select it from the local file input.
3. Confirm official SHA-256: `6862C034715DBF557C93C8F8AF8D8AA856CA8F4E62997660CEA9740F3EFDA356`.
4. Click **JTAG Debugger** in the WebUSB chooser. On Windows 11 N100, FT2232 Interface A (`MI_00`) uses WinUSB. FT2232 Interface B (`MI_01`) retains the FTDI virtual COM driver for Web Serial.
5. Program by the fixed runtime args `-c ft2232 -b tangnano9k pikosol.fs`. There is NO Flash option.
6. On successful openFPGALoader exit 0, check the actual board and HDMI, then open the adjacent Web Serial page.

## Implementation and dependencies

- HTML, JavaScript and CSS are hosted under this repository's GitHub Pages `/docs` root.
- The openFPGALoader WebAssembly/WebUSB runtime is pinned to `@yowasp/openfpgaloader@1.1.1-182.269` and self-hosted as `vendor/bundle.js` + `vendor/openFPGALoader.wasm` under the same GitHub Pages origin. A GitHub Actions workflow stages these pinned files; no runtime jsDelivr import is needed.
- The underlying mechanism follows `trabucayre/openFPGALoader_webUSB` but this page has an independent reduced fixed-profile GUI.
- `coi-serviceworker.js` is copied from https://github.com/gzuidhof/coi-serviceworker, MIT license, source includes MIT header. It supplies COOP/COEP for threaded WASM on GitHub Pages, which does not allow custom response headers.
- Browser USB permission is requested manually by the user on click and filtered to FTDI VID:PID 0403:6010.
- No background device access, automatic USB connection, or Flash writes.

## Hardware acceptance checklist (operator-verified)

- Page loads via GitHub Pages HTTPS with WebUSB available and crossOriginIsolated true.
- SHA-256 is checked for official local file.
- WebUSB chooser opens FT2232 JTAG device without altering FTDI UART driver.
- Local WASM module loads from GitHub Pages; the operator confirmed the actual board was programmed.
- Tang Nano 9K shows PiKoSoL v0.2.0 on HDMI.
- Web Serial can open Interface B after flashing and real commands such as INFO and LED ? work (operator confirmed).
- Auto-download: `./firmware/picorv32_lab04_hdmi_nano9k.fs` passes SHA-256 and is delivered by the checked GitHub Actions workflow.

This checklist is operator evidence for one tested configuration; not every error path has been independently exercised.

Original project: https://github.com/trabucayre/openFPGALoader_webUSB (Apache-2.0), https://github.com/YoWASP/openFPGALoader-web (ISC).


## KonSol RetroStation BREAKOUT RGB v0.1.0 — local WebUSB profile (26 October 2026)

The loader has a fourth profile **BREAKOUT RGB** for **Tang Nano 9K**, pinned to the operator-tested build SHA-256 `4CF80DBD008B0D41D4316BF63DB952190C03940A4FFB1FFC00CAB09210AE8789`.

**Current distribution rule:** the `.fs` is **not committed to the Pages firmware directory** and has **no downloadable release asset yet**. Select the **BREAKOUT RGB** profile, then use *Upload local .fs from computer* and select the exact local candidate `pikosol_breakout_rgb_nano9k.fs`. The loader verifies the hash against the pinned profile and rejects other binaries in this profile. The *Get from GitHub Pages* button is deliberately disabled in this profile until the independently verified asset is hosted. The existing three profiles and SRAM-only JTAG commands are unchanged.

**Important:** A successful HTML edit or GitHub Pages deployment is not browser hardware acceptance. Test the fourth profile with the exact known SHA in Chrome/Edge on the real board before documenting WebUSB BOARD PASS.

Sources, keyboard, proof and reproducible build: [`games/breakout-rgb/`](../../../games/breakout-rgb/). The original `PONG` browser keyboard does not expose Breakout's start command.


## BREAKOUT RGB v0.1.0 — verified release + Pages publisher

The exact 2,070,601-byte `.fs` asset is published at [Breakout v0.1.0 release](https://github.com/AIDevelopersMonster/Sipeed-FPGA/releases/tag/konsol-breakout-rgb-v0.1.0); verified SHA-256: `4CF80DBD008B0D41D4316BF63DB952190C03940A4FFB1FFC00CAB09210AE8789`.

The [Breakout publisher workflow](../../../.github/workflows/publish-konsol-breakout-pages.yml) stages this immutable checked release asset into the existing same-origin Pages firmware folder and updates the SHA256SUMS manifest. The fourth browser profile can now request the file from GitHub Pages, requiring BOTH the manifest and pinned profile hash match. **Workflow publication and browser-level programming must be separately verified; no new WebUSB hardware PASS is claimed by this change.** A local exact-hash `.fs` remains supported as fallback.

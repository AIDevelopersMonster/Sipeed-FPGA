# PiKoSoL SD-08 — conservative extension of existing LAB-04.4

Status: DRAFT PR #23, hardware acceptance of the modified browser UI pending. The original WebUSB loader and Web Serial Control Center passed board tests on 2026-10-23. The operator also confirmed that part of the existing browser workflow works with the SD-08 firmware on 2026-10-25; this is partial evidence, not full browser regression acceptance.

## Scope

- Preserve original `docs/index.html` and all existing WebUSB / Web Serial routes.
- Add a two-option firmware selector to existing `web-loader/index.html`: the default verified PiKoSoL v0.2.0, and hardware-tested SD-08.
- The original JTAG SRAM programming function, pinned YoWASP WASM, same-origin files, service worker and FT2232 device selection are unchanged.
- Add FAT32 `SD 0`, `FS`, `DIR` buttons and short 8.3 `TYPE` entry to the existing Control Center. Use its existing real UART send queue.
- No second website, no duplicate WebUSB engine, no extra UART connection, and absolutely no embedded FPGA Flash writes. SD-08 remains read-only as a tested baseline; SD-card file writes are a separate, explicitly authorized follow-up experiment.

## Bitstream identity

- Default v0.2.0: `picorv32_lab04_hdmi_nano9k.fs`, SHA-256 `6862c034715dbf557c93c8f8af8d8aa856ca8f4e62997660cea9740f3efda356`.
- SD-08: `sd08_pikosol_fat32_readonly.fs`, SHA-256 `37ddb2fb7d20f7e4ad610dad4160dc98ed38e5197221b62644642d32c8c09f4b`.
- SD-08 operator board evidence: `INFO`, `FS`, `DIR`, `TYPE PIKO.TXT` yielded `PiKoSoL SD08 FAT32 TYPE PASS` on 2026-10-25. Browser UI buttons themselves not yet independently accepted.
- SD-08 currently has a known command alias defect: `SD INFO` is incorrectly routed; use `FS` instead.

## SD-08 GitHub Pages image publication

The build artifact resides on the operator PC:
`C:\GitHub\Sipeed-FPGA-LAB05\boards\tang-nano-9k\experiments\sd07-pikosol-mmio\build\board_fat32_20261025_123935_295\sd08_pikosol_fat32_readonly.fs`

Before public SD-08 download can work, verify the above file on the operator PC and publish it as a release asset named `sd08_pikosol_fat32_readonly.fs` under tag `pikosol-sd08-fat32-ro`. The included GitHub Actions workflow downloads only this asset, validates the pinned SHA-256 and stages it in the original Pages firmware folder. Until the release is published, the original WebUSB page can load the verified SD-08 from a local .fs file.

## Required acceptance after PR review

1. Validate the unchanged original v0.2.0 browser scenario: SHA-256, SRAM WebUSB upload, Web Serial INFO/LED, TERM/GFX/KEYS, HDMI.
2. Validate SD-08: select its profile, load the exact local .fs in SRAM via browser; Web Serial `INFO`, `FS`, `DIR`, `TYPE PIKO.TXT` and physical HDMI.
3. Validate both automatic same-origin download buttons after the new SD-08 release asset has been staged.
4. Keep the PR draft and keep `main` unchanged until tests are accepted.

## Separate follow-up, not part of SD-08

User clarified the vendor/seller firmware name as `PicoSoc`. Its exact image and any recovery procedure are not yet identified. Do not assume Sipeed PicoTiny or any arbitrary example is that image. Do not attempt Flash programming in this PR.

## Acceptance note — 2026-10-25

Operator accepted the preserved look and verified portions of the existing browser workflow using the SD-08 image on another Windows computer. **This is acceptance of the additive web UI integration with documented exceptions, not a claim that every WebUSB programming mode has passed new physical tests.** The operator reports that the other UI features work, and local-file programming may work; this machine's FT2232 JTAG drivers have not been independently confirmed.

The automated firmware download behaves differently depending on origin and binary publication:

- On an unpacked `file://` copy, the browser may reject `fetch("./firmware/...")` under local-file origin restrictions. The original HTML/CSS remain usable without an HTTP server; the firmware auto-fetch requirement applies to the trusted HTTPS GitHub Pages deployment.
- On GitHub Pages, the existing v0.2.0 image is hosted at `./firmware/picorv32_lab04_hdmi_nano9k.fs`; the SD-08 image is **not yet uploaded**, so SD-08 auto-fetch is expected to fail until the pinned Release asset and publication workflow have completed.
- WebUSB USB/JTAG device permissions and Windows WinUSB drivers are a *separate* concern from downloading the .fs file over HTTP.

The SD-08 profile may be selected with a verified local `.fs` already on disk. No persistent FPGA Flash actions were added. PicoSoc factory firmware identification remains a separate future investigation.

## Experimental SD-card write policy (operator clarification, 2026-10-25)

The operator has **two SD cards**, including a second card specifically unpacked for development. Their current contents have **no preservation value** and may be overwritten for SD write experiments. The previous assumption that SD-card contents must be protected was incorrect. Do not confuse **SD-card writes** (allowed on the expendable test card) with **FPGA configuration SPI Flash writes** (still outside this browser PR, pending recovery validation).

Acceptance gates for a future isolated `SD-WRITE-01` experiment, without changing the hardware-tested SD-08 read-only bitstream:

1. On the host PC, identify the removable card by capacity/device identity and verify that it is the expendable test card. Reformat FAT32 and place a known test file on it; user-visible confirmation is needed before any destructive host-side action. Never assume a drive letter.
2. Start with an isolated SPI CMD24 single-sector write to a **known scratch LBA**, after recording the sector's original 512 bytes; read it back via CMD17 and require byte-for-byte comparison and CRC checks where implemented. Keep writes away from MBR, VBR, FAT and directory structures at this gate.
3. Only after repeatable physical CMD24 pass, implement a narrow FAT32 create/overwrite path in a separate version: allocate clusters, update the appropriate FAT copies and directory entry with failure handling. Initial support may be restricted to short 8.3 names and one file, with an explicitly destructive test card. Verify on FPGA and by remounting on PC.

**Stop rule:** at most three documented on-board tests. If the same problem persists, stop firmware rewrites and inspect power, SD wiring, signal timing, CRC and card compatibility. Do not assert any SD-card write hardware PASS until logs demonstrate CMD24 and readback. No write command should be exposed in the public Web Serial UI until that firmware exists and passes board verification.

## Downloaded upstream reference files

The operator downloaded `picotiny.fs` and `example-fw-flash.v` on 2026-10-25, and both passed comparison against the operator's pinned SHA-256 values. Their exact full hashes, provenance URL and on-board behavior have not been supplied in this repository. `picotiny.fs` is an FPGA configuration, while `example-fw-flash.v` is not a Gowin `.fs` bitstream and must not be offered to the existing JTAG SRAM loader. The vendor/seller's `PicoSoc` firmware must not be equated with PicoTiny without identifying evidence. The existing web selector remains limited to v0.2.0 and SD-08 until a third profile can be sourced, hash-pinned and tested.

# PiKoSoL SD-08 — conservative extension of existing LAB-04.4

Status: DRAFT PR #23, hardware acceptance of the modified browser UI pending. The original WebUSB loader and Web Serial Control Center passed board tests on 2026-10-23. The operator also confirmed that part of the existing browser workflow works with the SD-08 firmware on 2026-10-25; this is partial evidence, not full browser regression acceptance.

## Scope

- Preserve original `docs/index.html` and all existing WebUSB / Web Serial routes.
- Add a two-option firmware selector to existing `web-loader/index.html`: the default verified PiKoSoL v0.2.0, and hardware-tested SD-08.
- The original JTAG SRAM programming function, pinned YoWASP WASM, same-origin files, service worker and FT2232 device selection are unchanged.
- Add FAT32 `SD 0`, `FS`, `DIR` buttons and short 8.3 `TYPE` entry to the existing Control Center. Use its existing real UART send queue.
- No second website, no duplicate WebUSB engine, no extra UART connection, no SD writes, and absolutely no embedded Flash writes.

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

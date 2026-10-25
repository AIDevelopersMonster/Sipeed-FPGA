# PiKoSoL SD-08 Web Lab — publication and hardware gates

Status: web integration is a review candidate; physical WebUSB/Web Serial acceptance on this new HTML page has NOT yet been performed.

## Firmware

- v0.2.0: SHA-256 6862c034715dbf557c93c8f8af8d8aa856ca8f4e62997660cea9740f3efda356; UART/HDMI/GFX hardware pass.
- SD-08: SHA-256 37ddb2fb7d20f7e4ad610dad4160dc98ed38e5197221b62644642d32c8c09f4b; 25.10.2026 hardware pass for INFO, FS, DIR, TYPE PIKO.TXT.
- Official Sipeed PicoTiny example: SHA-256 5a9558e4b0ad2dad2812ad90757bfe6a27f6367992bf536a3304bc948a41659e, source https://github.com/sipeed/TangNano-9K-example/blob/main/picotiny/picotiny.fs
- Official Sipeed HDMI example: SHA-256 830bd2affecee53ce344fdb518ddfea70ca22655d0cb0595af1de921098d339f, source https://github.com/sipeed/TangNano-9K-example/blob/main/hdmi/picotiny.fs

Neither Sipeed example is proven to be the exact original factory firmware installed on this physical board. These files are linked from upstream, NOT redistributed as our factory recovery release.

## Site

Unified test page: docs/lab04/web-loader/release.html. It reuses the already-hosted WebUSB COI service worker and pinned openFPGALoader WebAssembly runtime.
All FPGA programming on this page is temporary SRAM only, using the already hardware-tested ft2232/tangnano9k profile.
Web Serial (COM interface B) is real 115200 8N1 UART. Commands are INFO, SD 0, FS, DIR, LED ? and TYPE filename (strict 8.3). The browser does not emulate a file system.
SD INFO has a known dispatcher bug in this SD-08 firmware: use FS. Long names, nested directories, writes, large and fragmented file reads are not board accepted.

## Publishing SD-08

1. Review the PR and merge it to main; new page link then becomes visible.
2. Locate the original accepted local file on the operator computer: C:\GitHub\Sipeed-FPGA-LAB05\boards\tang-nano-9k\experiments\sd07-pikosol-mmio\build\board_fat32_20261025_123935_295\sd08_pikosol_fat32_readonly.fs
3. Check Get-FileHash -Algorithm SHA256 against 37DDB2FB7D20F7E4AD610DAD4160DC98ED38E5197221B62644642D32C8C09F4B. Never substitute a new build without repeating hardware acceptance.
4. On the operator PC, use GitHub CLI (gh release create pikosol-sd08-fat32-ro <absolute-fs-path> -R AIDevelopersMonster/Sipeed-FPGA --target main --title 'PiKoSoL SD-08 FAT32 read-only' --notes 'Read-only FAT32: FS, DIR and TYPE verified on Tang Nano 9K, 25 October 2026.').
5. Workflow publish-pikosol-sd08-pages.yml runs on publication of that exact release tag or manually, verifies the file SHA-256 and copies it to docs/lab04/web-loader/firmware/.
6. Hardware-test the new public page in Chromium: SHA-256, WebUSB SRAM, INFO, FS, DIR, TYPE PIKO.TXT. Verify independent HDMI display and retest v0.2.0 regression.

## Nonvolatile embedded Flash — blocked until recovery is verified

Official Gowin SUG502E section 4.8 documents index 6 (embFlash Erase,Program,Verify), as distinct from SRAM operation 2. Source: https://cdn.gowinsemi.com.cn/SUG502E.pdf
Do NOT run it before obtaining and testing a trustworthy recovery image, confirming JTAG recovery after power-cycle, and verifying compatibility on this actual board. The browser Flash button is not present.
Never confuse FPGA embedded configuration Flash with an external SPI firmware chip or the FAT32 SD card.

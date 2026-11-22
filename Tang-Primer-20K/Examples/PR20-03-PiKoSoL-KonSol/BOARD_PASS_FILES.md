# PiKoSoL TP20 — verified working files

Board: Tang Primer 20K Dock, GW2A-18C, PicoRV32 RV32I, HDMI, COM10 115200 8N1.
FPGA .fs source: THLN33/System_picoRV32 at commit d3e24d9176c9361cb583111775f39a9a08cabf52 (MIT).
Verified FPGA Git blob SHA1: 5bb54a84311a62e1b0aadd11671c399561838b24.
FPGA image programmed to SRAM only; no Flash.

Board results: original bitstream SRAM PASS; monitor XMODEM-CRC 145/145 ACK;
demo.bin RUN -> RULE30 checksum 0xD2A3C779 -> returned to PiKoSoL;
Live Keyboard typed directly on HDMI; operator reported File Manager v0.1.4
and custom PKD1 applications working (2026-11-20).
Individual video screenshots/logs of each new app are not included.

Apps named LCD_20X4_PREVIEW, RGB_WS2812_PREVIEW and AUDIO_PT8211_PREVIEW
display previews on HDMI. They DO NOT drive external LCD, WS2812 or PT8211.
This is a bare-metal PicoRV32 computer, not a standalone filesystem.
Use scripts/Sync-PiKoSoL-From-GitHub.ps1 to download/verify the exact files.

No untested candidate versions, GitHub Release, branch or tag.
## Дополнение 2026-11-22 — GPIO / PMOD V3714

Полное описание, MMIO-адреса, CST-пины и пять аттестованных по файлам `.bin`: [GPIO-PMOD-V3714/README.md](GPIO-PMOD-V3714/README.md). **Обновление от 2026-11-22, аппаратные наблюдения оператора:** PMOD0 — отдельный тест; PMOD1 **вместе с PMOD2** — совместный тест; PMOD3 — отдельный тест. На **всех четырёх PMOD** подтверждена видимая реакция внешних LED: **BOARD PASS (port-level LED response)**. Встроенные LED, GPIO LIVE и ALL LED OFF также физически подтверждены. **Не утверждается** полный `8/8 physical pin-map PASS` для PMOD2/3 и не приписывается отдельная проверка непоименованным BIN без точного SHA256. Заводская Flash не изменялась. Рабочая GPIO `.fs` идентифицирована по SHA256 в описании, но её файл в текущем комплекте для публикации отсутствует.

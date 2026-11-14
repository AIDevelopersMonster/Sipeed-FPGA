# RTL IP — переносимые компоненты

Общий принцип: **один исходник каждого IP-блока**, независимый от модели FPGA и процессора. Платозависимая физика — в `boards/`, самостоятельные примеры — в `examples/peripherals/`, готовые SoC — в `systems/`.

Текущий `ip/` — реестр **существующих** HDL, а не уже выполненная миграция:

| IP | Канонический исходник сегодня | Уровень проверки |
| --- | --- | --- |
| SPI | `01-PicoRV32/lab05/rtl/lab05_spi_byte.v` | RTL PASS, используется SD-зондом |
| SDHC CMD17 LBA0 | `01-PicoRV32/lab05/rtl/lab05_sd_init_read0.v` | HARDWARE PASS в SD-зонде |
| SDHC multi-LBA | `01-PicoRV32/lab05/rtl/lab05_sd_read_sector.v` | Экспериментальный |
| UART | `01-PicoRV32/rtl/uart_tx_8n1.v`, `uart_rx_8n1.v` | RTL PASS, используется PiKoSoL |
| HDMI/SVO | `01-PicoRV32/lab04/rtl/` + pinned PicoTiny | аппаратная проверка в PiKoSoL |

После завершения LAB-05 физическое выделение в `ip/<interface>/rtl/` выполняется **отдельным небольшим изменением с регрессией**. Проверенные LAB-04/05 не передвигаем: они остаются воспроизводимыми историческими снимками. `common/` остаётся местом для программно видимого MMIO-контракта, не копией RTL.


## Additional candidates (2026-11-14)

- [Sipeed Tang Primer 25K UART — full Verilog source, ASCII demo](uart/sipeed-primer25k/README.md): verified **original prebuilt** hardware UART Hello output; translated source is **not yet rebuilt or tested**.
- [NESTang-25K NES system — candidate for IP extraction](candidates/nestang-25k.md): interesting integrated project (HDMI, SD, SDRAM, USB HID). Requires SDRAM, not tested on this lab.

- [**A2600Nano v2.5 — HDMI + audio, Tang Primer 25K**](hdmi/a2600nano-primer25k/README.md): полный исходный .fs дал **BOARD PASS (картинка + звук)**, точные исходники 24 файлов, PLL/TMDS/ELVDS, ограничения и GPL-3.0 сохранены; **самостоятельный PR25-08 собран и сообщил BOARD WORKING**, звук/STA/S2 подлежат отдельной фиксации. PiKoSoL не изменён.

- [PR25-09 HDMI AUDIO DIAG](../Tang-Primer-25K/Examples/PR25-09-HDMI-AUDIO-DIAG/README.md): independent follow-up after PR25-08 VIDEO PASS/AUDIO FAIL; tests intermittent HDMI stereo tone and an on-screen generator marker. **Source only, no build or hardware PASS yet.**

- [thisiseth Tang Primer 25K — second HDMI+audio implementation](hdmi/thisiseth-tp25k-audio/README.md): original author reports real 720p60 + 16-bit 48kHz stereo, complete FPGA-side HDMI source, 720p PLL and audio FIFO, pinned MIT + upstream notices. **Reference source only, standalone test NOT built**. Original full application needs ESP32-S3 for PCM supply; no external SDRAM required.

- [Brus-16 Tang Primer 25K SFX firmware candidate](hdmi/BRUS16_TP25K_AUDIO_CANDIDATE_RU.md): separate July 2026 ready tp25k.zip with author-reported HDMI sound (Gerion), no SDRAM / ESP32-S3, 44.1kHz SFX, full sources and pin constraints. **Not our hardware BOARD PASS; original source not copied.**

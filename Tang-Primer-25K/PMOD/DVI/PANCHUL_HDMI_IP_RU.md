# Tang Primer 25K — учебный DVI от Юрия Панчула и открытый HDMI со звуком

**Проверено по исходникам 15.11.2026. Только SOURCE REVIEW.** Мы не собирали и не загружали на плату новые прошивки из этих источников. Наш подтверждённый видео+аудио эталон — [A2600Nano Golden и PR25-13](WORKING_PROJECTS_RU.md).

## 1. Что конкретно найдено у Юрия Панчула

**Репозиторий:** [yuri-panchul/basics-graphics-music](https://github.com/yuri-panchul/basics-graphics-music), закреплённый commit [817bd4dac8ab45d5c22bdd78b441bedb80672cd0](https://github.com/yuri-panchul/basics-graphics-music/tree/817bd4dac8ab45d5c22bdd78b441bedb80672cd0). Код курса в целом под MIT, но используемый защищённый Gowin DVI_TX — IP производителя; его нельзя трактовать как открытый HDL.

- **Плата и подключение:** [boards/tang_primer_25k_pmod_hdmi](https://github.com/yuri-panchul/basics-graphics-music/tree/817bd4dac8ab45d5c22bdd78b441bedb80672cd0/boards/tang_primer_25k_pmod_hdmi).
- **Верхний уровень:** [board_specific_top.sv](https://github.com/yuri-panchul/basics-graphics-music/blob/817bd4dac8ab45d5c22bdd78b441bedb80672cd0/boards/tang_primer_25k_pmod_hdmi/board_specific_top.sv) определяет USE_PMOD_DVI и включает [общий board_specific_top.sv](https://github.com/yuri-panchul/basics-graphics-music/blob/817bd4dac8ab45d5c22bdd78b441bedb80672cd0/boards/tang_primer_25k_pmod_vga/board_specific_top.sv); это **не самостоятельный однофайловый проект**.
- **Распиновка:** [board_specific.cst](https://github.com/yuri-panchul/basics-graphics-music/blob/817bd4dac8ab45d5c22bdd78b441bedb80672cd0/boards/tang_primer_25k_pmod_hdmi/board_specific.cst) задаёт дифференциальные пары **clock H5/J5, D0 H8/H7, D1 G7/G8, D2 F5/G5**, 50 MHz E2, UART_RX B3 и UART_TX C3. Это те же четыре TMDS FPGA pin-пары, что и в рабочем A2600Nano. **Названия PMOD0/PMOD2 в текстовых комментариях разных проектов не согласованы: ориентир — конкретные FPGA пины и проверенная физическая установка, а не условный номер разъёма.**
- **Графический генератор:** [vga.sv](https://github.com/yuri-panchul/basics-graphics-music/blob/817bd4dac8ab45d5c22bdd78b441bedb80672cd0/peripherals/vga.sv) формирует x/y, hsync, vsync, DE, pixel clock; [lab_top.sv — цветовые полосы](https://github.com/yuri-panchul/basics-graphics-music/blob/817bd4dac8ab45d5c22bdd78b441bedb80672cd0/labs/2_graphics/2_3_color_stripes/lab_top.sv) формирует RGB.
- **Передатчик:** [DVI_TX_Top из dvi_tx.ipc и dvi_tx.v](https://github.com/yuri-panchul/basics-graphics-music/tree/817bd4dac8ab45d5c22bdd78b441bedb80672cd0/boards/tang_primer_25k_pmod_hdmi). Входы: I_serial_clk, I_rgb_clk, I_rgb_vs, I_rgb_hs, I_rgb_de, I_rgb_r/g/b; выходы O_tmds_clk_p/n, O_tmds_data_p/n. [gowin_pll.ipc](https://github.com/yuri-panchul/basics-graphics-music/blob/817bd4dac8ab45d5c22bdd78b441bedb80672cd0/boards/tang_primer_25k_pmod_hdmi/gowin_pll/gowin_pll.ipc) задаёт выход 125 MHz; учебный растр 640x480 25 MHz.
- **Сборка:** [board_specific.tcl](https://github.com/yuri-panchul/basics-graphics-music/blob/817bd4dac8ab45d5c22bdd78b441bedb80672cd0/boards/tang_primer_25k_pmod_hdmi/board_specific.tcl) и [board_specific.sdc](https://github.com/yuri-panchul/basics-graphics-music/blob/817bd4dac8ab45d5c22bdd78b441bedb80672cd0/boards/tang_primer_25k_pmod_hdmi/board_specific.sdc) рассчитаны на GW5A-LV25MG121NC1/I0 / Gowin EDA. Для курса обычно требуется Git Bash и набор общих скриптов, см. [README](https://github.com/yuri-panchul/basics-graphics-music/blob/817bd4dac8ab45d5c22bdd78b441bedb80672cd0/README.md).

**Принципиальная граница:** это **DVI-видеотракт**. В портах DVI_TX_Top **нет аудиосэмплов, clk_audio, ACR, Audio InfoFrame**, значит этот передатчик **не обеспечивает звук внутри HDMI**. Курс также содержит i2s_audio_out, но он выдаёт звук **отдельно на PMOD_2**, а не в HDMI. Наличие на одной FPGA модулей DVI и I2S не равно HDMI+audio. Поэтому **берём Панчула как учебный эталон разделения video generator / sync / serializer**, но **не как готовый HDMI+audio кодек**.

## 2. Отдельный открытый HDMI + AUDIO непосредственно для GW5A-25A

**Оригинал:** [thisiseth/tang-primer-25k-spi-io](https://github.com/thisiseth/tang-primer-25k-spi-io/tree/cce99075f06d0946c8a70c221118df2c4b57fe2a/src/fpga/spi_io_bridge), upstream commit cce99075f06d0946c8a70c221118df2c4b57fe2a.

**Это уже сохранено в нашем GitHub:** [ip/hdmi/thisiseth-tp25k-audio](../../../ip/hdmi/thisiseth-tp25k-audio/README.md); [побайтовый снимок 22 файлов](../../../ip/hdmi/thisiseth-tp25k-audio/vendor/src/). Не плодить дубликаты.

- [vendor/src/hdmi/hdmi.sv](../../../ip/hdmi/thisiseth-tp25k-audio/vendor/src/hdmi/hdmi.sv) (открытый hdl-util-передатчик; MIT/Apache-2.0) принимает **rgb[23:0], clk_pixel, clk_pixel_x5, clk_audio, stereo audio_sample_word[1:0]**, возвращает TMDS.
- [vendor/src/top.sv](../../../ip/hdmi/thisiseth-tp25k-audio/vendor/src/top.sv): VIDEO_ID_CODE=4, DVI_OUTPUT=0, AUDIO_RATE=48000, видео 720p60, аудио 16-bit stereo, источник FIFO.
- [PLL 720p](../../../ip/hdmi/thisiseth-tp25k-audio/vendor/src/gowin/pll_hdmi_720.ipc), [FIFO аудио](../../../ip/hdmi/thisiseth-tp25k-audio/vendor/src/gowin/fifo_audio.ipc), [конкретные пины](../../../ip/hdmi/thisiseth-tp25k-audio/vendor/src/pins.cst), [системный SDC](../../../ip/hdmi/thisiseth-tp25k-audio/vendor/src/timing.sdc).
- Авторский полный стенд использует ESP32-S3 как SPI-мастер для данных изображения и звука. Отдельная FPGA-часть HDMI и BRAM обходится без внешней SDRAM. Наш снимок **не является полным оригинальным компилируемым проектом**, потому что USB-часть в нём не зеркалирована; для полной сборки необходим весь upstream.

**Не смешивать разные версии HDMI-core и packet_picker/serializer пофайлово:** брать согласованное семейство из одного исходника вместе с PLL, ограничениями, reset и физическими TMDS-выходами. Исходный thisiseth сам сообщает об успешной работе, но на **нашем** Primer 25K именно этот код пока не проверен.

## 3. Что принимаем как исходную основу

| Задача | Принятое решение | Уровень проверки |
| --- | --- | --- |
| Учебное разделение видео и DVI-вывода | **Yuri Panchul** (vga.sv + DVI_TX_Top + board wrapper + CST) | SOURCE REVIEW, **не наш BOARD PASS** |
| Открытый reusable HDMI-core с настоящим аудио | **thisiseth + hdl-util/hdmi** (в нашем ip/hdmi уже сохранён) | SOURCE SNAPSHOT, **не наш BOARD PASS** |
| Реально доказанный видео+звук на физической плате | **A2600Nano Golden и наша PR25-13** | **BOARD VIDEO+AUDIO PASS** |

**Важное ограничение:** если сначала собрать защищённый DVI_TX Панчула, звук в него нельзя просто «добавить» подключением I2S. Для HDMI-аудио требуется **другой пакетизатор HDMI** (готовый thisiseth/hdl-util либо сохранённый проверенный A2600 HDMI). Поэтому на будущее есть два самостоятельных пути, но не одна произвольная смесь.

**Работа по PR25 остаётся приостановленной до получения SDRAM.** Этот файл — аудит и выбор исходного эталона, не обещание готовой новой прошивки, не BUILD PASS и не новый BOARD PASS.

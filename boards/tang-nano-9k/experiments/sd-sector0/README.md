# SD-01 / Tang Nano 9K — независимый аппаратный эксперимент

Частный случай общего направления [SDHC](../../../../examples/peripherals/sd-card/01-sector-read/README.md). Здесь находятся **локальные RTL, тесты, CST/SDC и сборочные скрипты**. Это самостоятельный FPGA-проект: PicoRV32 и HDMI не используются.

Из корня Sipeed-FPGA:

```powershell
& .\boards\tang-nano-9k\experiments\sd-sector0\test.ps1
& .\boards\tang-nano-9k\experiments\sd-sector0\build.ps1
```

Ни один скрипт не программирует FPGA и не записывает на SD. После проверки PnR/STA bitstream можно вручную загрузить только в **SRAM**, открыть UART 115200 8N1 и нажать физическую **S2**.

Исходная LAB-05.1 аппаратно прошла проверку 24 октября 2026 года: `SD PASS SIG=55AA` дважды. Этот проект основан на **копии исходных файлов**, но его новая сборка и отдельная аппаратная приёмка ещё не выполнены. Не присваивать статус исходного испытания новой сборке автоматически.

Технология: SPI mode 0, SDHC CMD0/8/55/41/58/17, 512-byte LBA0, CRC16. Линии SD 36/37/38/39, уровни 3.3 V. Только чтение; FAT32/запись файлов здесь не реализованы.

Дублирование HDL и скриптов допустимо: это *версионированный исследовательский снимок*, который вправе расходиться с общим IP. Происхождение фиксируется в `experiment.json`.


## English-language technical booklet

[**SD and microSD on FPGA** (English PDF)](../../../../docs/education/SD_FPGA_EN_v0.1.pdf) · [Editable manuscript](../../../../docs/education/SD_FPGA_EN_v0.1.md).

The English edition distinguishes the published Verilog reference from illustrative SystemVerilog/VHDL designs. DOI pending author-supplied publication identifier.

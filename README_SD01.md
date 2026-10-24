# SD-01 FPGA ↔ microSDHC: независимая лабораторная

**[Исходники SD-01 на Tang Nano 9K](boards/tang-nano-9k/experiments/sd-sector0/README.md)** · **[SPI-01: базовый обмен](examples/peripherals/spi/01-mode0-byte/README.md)** · **[Общий каталог](examples/peripherals/README.md)**.

SD-01 не требует процессора RISC-V/PicoRV32. FPGA выполняет SDHC SPI-команды, принимает 512 байт сектора 0, проверяет CRC16 и выдаёт ответ через аппаратный UART. Оператор получил дважды `SD PASS SIG=55AA` на исходной LAB-05.1 (24 октября 2026).

**Важно:** самостоятельно опубликованный исходный снимок должен быть отдельно проверен (RTL → Gowin PnR/STA → реальное железо). Прежний результат не переносится автоматически на другую сборку. Разработка PiKoSoL с FAT32 и multi-LBA остаётся в отдельной экспериментальной ветке.

Полезны и результаты неудач: они документируют ограничения аппаратного протокола, пины/электрику, тайминги и пределы подхода — даже если их код больше не нужен PiKoSoL.

## Published educational booklets (Zenodo)

- [SPI on FPGA — DOI: 10.5281/zenodo.23608792](https://doi.org/10.5281/zenodo.23608792)
- [SD and microSD on FPGA — DOI: 10.5281/zenodo.23608853](https://doi.org/10.5281/zenodo.23608853)

Original PDF/English Markdown editions: [docs/education](docs/education/README.md). Source code remains independent of the publication metadata.

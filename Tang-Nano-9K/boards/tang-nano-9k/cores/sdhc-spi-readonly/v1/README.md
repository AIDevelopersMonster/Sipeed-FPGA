# Reusable read-only SDHC SPI core v1

Canonical source snapshot for NEW labs starting SD-04; no behavioral changes.

- `rtl/spi_byte.v` copied from `experiments/sd-multilba/rtl/spi_byte.v` on repository main.
- `rtl/sd_read_sector.v` copied byte-for-byte from `experiments/sd-multilba/rtl/sd_read_sector.v` on repository main.
- Verilog modules: `lab05_spi_byte` and `lab05_sd_read_sector`.
- Contract: 27 MHz clk, SPI mode 0, SDHC init and CMD17 at 512-byte LBA, synchronous `peek_data` from 512-byte BSRAM, `done`, `busy`, and error codes.
- This is read-only and does not expose FAT32 directory processing.

Legacy SD-01, SD-02 and SD-03 remain unchanged and frozen. Simulation of the SDHC core is inherited from SD-02 testbenches; the new SD-04 module must pass independent testing before physical FPGA acceptance.

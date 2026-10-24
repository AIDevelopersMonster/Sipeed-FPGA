# FPGA Digital Interfaces — SPI and SD (English v0.1)

Two illustrated, editable technical teaching manuscripts with corresponding downloadable PDFs. Both include experimental provenance, Verilog reference examples, SystemVerilog/VHDL architectural sketches, internal testbenches, external scripts, and acceptance criteria.

| Booklet | PDF | Editable source |
|---|---|---|
| SPI on FPGA: From the Bus to Verified RTL | [SPI PDF](SPI_FPGA_EN_v0.1.pdf) | [SPI Markdown](SPI_FPGA_EN_v0.1.md) |
| SD and microSD on FPGA | [SD PDF](SD_FPGA_EN_v0.1.pdf) | [SD Markdown](SD_FPGA_EN_v0.1.md) |

**Actual source code:** [SPI-01](../../examples/peripherals/spi/01-mode0-byte/) · [SD-01 for Tang Nano 9K](../../boards/tang-nano-9k/experiments/sd-sector0/). [Frozen FPGA source revision](https://github.com/AIDevelopersMonster/Sipeed-FPGA/commit/5b4ba62506131a3e5ada078008b1904fd6a7ae48) · [RTL CI](https://github.com/AIDevelopersMonster/Sipeed-FPGA/actions/runs/40052632010) · [Hardware video](https://youtu.be/ybEUMzt7Gqg).

**Evidence boundary:** original SD probe hardware result: `SD PASS SIG=55AA` twice; standalone published SD-01 has RTL CI PASS, not independently retested bitstream. SystemVerilog and VHDL portions are educational sketches, not certified alternate implementations.

**DOI:** pending author-supplied identifiers; do not infer one from a different project.

PDF is the publication/viewing artifact; Markdown is the maintained source. Editable Markdown references figures under `assets/`; the PDFs contain the fully rendered diagrams. The complete authoring package with image assets and PDF-build scripts can also be downloaded from the accompanying publication bundle.

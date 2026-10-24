# FPGA Digital Interfaces — SPI and SD (English v0.1)

Two illustrated, editable technical teaching manuscripts with corresponding downloadable PDFs. Both include experimental provenance, Verilog reference examples, SystemVerilog/VHDL architectural sketches, internal testbenches, external scripts, and acceptance criteria.

| Booklet | PDF | Editable source |
|---|---|---|
| SPI on FPGA: From the Bus to Verified RTL | [SPI PDF](SPI_FPGA_EN_v0.1.pdf) | [SPI Markdown](SPI_FPGA_EN_v0.1.md) |
| SD and microSD on FPGA | [SD PDF](SD_FPGA_EN_v0.1.pdf) | [SD Markdown](SD_FPGA_EN_v0.1.md) |

**Actual source code:** [SPI-01](../../examples/peripherals/spi/01-mode0-byte/) · [SD-01 for Tang Nano 9K](../../boards/tang-nano-9k/experiments/sd-sector0/). [Frozen FPGA source revision](https://github.com/AIDevelopersMonster/Sipeed-FPGA/commit/5b4ba62506131a3e5ada078008b1904fd6a7ae48) · [RTL CI](https://github.com/AIDevelopersMonster/Sipeed-FPGA/actions/runs/40052632010) · [Hardware video](https://youtu.be/ybEUMzt7Gqg).

**Evidence boundary:** original SD probe hardware result: `SD PASS SIG=55AA` twice; standalone published SD-01 has RTL CI PASS, not independently retested bitstream. SystemVerilog and VHDL portions are educational sketches, not certified alternate implementations.

## Zenodo publications and citations

| Publication | Zenodo DOI | Original PDF (v0.1) | DOI-linked editable reprint (v0.1.1) |
|---|---|---|---|
| SPI on FPGA: From the Bus to Verified RTL | [10.5281/zenodo.23608792](https://doi.org/10.5281/zenodo.23608792) | [SPI v0.1 PDF](SPI_FPGA_EN_v0.1.pdf) | [SPI v0.1.1 Markdown](SPI_FPGA_EN_v0.1.1.md) |
| SD and microSD on FPGA | [10.5281/zenodo.23608853](https://doi.org/10.5281/zenodo.23608853) | [SD v0.1 PDF](SD_FPGA_EN_v0.1.pdf) | [SD v0.1.1 Markdown](SD_FPGA_EN_v0.1.1.md) |

The DOIs were supplied by the publication author on 24 October 2026. The repository's original v0.1 PDFs remain unchanged. v0.1.1 is a bibliographic-only update, **not a claim that GitHub v0.1.1 is the exact file deposited at Zenodo**. Open the DOI landing pages for the authoritative registered metadata. The DOI-linked v0.1.1 reprint PDFs can be independently regenerated from the editable source with the booklet build assets.



## Follow-up hardware demonstration: SD-02.1

The read-only multi-LBA FPGA experiment is archived separately from the SD-01 teaching reference: [SD-02.1 code and hardware acceptance](../../boards/tang-nano-9k/experiments/sd-multilba/) · [author-supplied video](https://youtu.be/KdMJc_Ly7fQ). The operator-reported hardware run read four LBAs (0, 1, 2048 and 65541) and printed `SD02 PASS`; FAT32 access is not part of that test.

PDF is the publication/viewing artifact; Markdown is the maintained source. Editable Markdown references figures under `assets/`; the PDFs contain the fully rendered diagrams. The complete authoring package with image assets and PDF-build scripts can also be downloaded from the accompanying publication bundle.

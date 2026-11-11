# SD-02.1 / LAB-05.2 — hardware acceptance, 24 October 2026

**Verdict: HARDWARE FUNCTIONAL PASS (defined four-sector test).**
Source: operator-supplied Gowin reports, SRAM programmer output, and UART terminal capture on a physical Tang Nano 9K. No live access to the operator's board was available to the recording assistant.

## Reproducibility and artifact identity

- Board: Sipeed Tang Nano 9K, FPGA `GW1NR-9C (0x1100481B)`.
- Programmed test design: `sd02_multilba_probe_top`; no PicoRV32, HDMI, or firmware.
- Source: `agent/lab05-sd02-multilba`, independent from the frozen SD-01 and PiKoSoL v0.2.0.
- Programmer: Gowin FT2CH / JTAG at 2.5 MHz; `SRAM Program` (operation index 2) completed 100%, exit 0; user code `0x0000D6D5`, status `0x0003F020`. No configuration Flash operation.
- Bitstream: `sd02_multilba_nano9k.fs`.
- Windows output directory: `build/run_20261024_072817_002_a80862/`.
- Independently checked bitstream SHA-256:
  `D8B68A37FFFE9A4DE9B3B68C7CD9079BCC191840CF82C1EDBD2F220AD3D9BD66`.
- Hardware UART: 115200 baud, 8N1, after FPGA reset.
- Local Gowin source manifest and full PnR reports were retained by the operator and not uploaded as part of this text-only receipt.

## Author's video record

- **Video supplied by the experiment author:** [SD-02.1 — FPGA microSD multi-LBA hardware demonstration](https://youtu.be/KdMJc_Ly7fQ).
- Recorded as a complementary demonstration link; the URL itself has not been independently reviewed against the local bitstream and terminal output. The verbatim UART capture below remains the primary record of the operator-reported run.

## Physical UART capture — verbatim

```text
SD02 LBA=00000000 CRC=0ED7 H=0000 T=55AA E=00
SD02 LBA=00000001 CRC=0000 H=0000 T=0000 E=00
SD02 LBA=00000800 CRC=0000 H=0000 T=0000 E=00
SD02 LBA=00010005 CRC=D7D7 H=843D T=6861 E=00
SD02 PASS
```

| Decimal LBA | Hex LBA | RAM CRC16 | First bytes | Last bytes | Card read error |
|---:|---|---|---|---|---|
| 0 | `00000000` | `0ED7` | `0000` | `55AA` | `00` |
| 1 | `00000001` | `0000` | `0000` | `0000` | `00` |
| 2048 | `00000800` | `0000` | `0000` | `0000` | `00` |
| 65541 | `00010005` | `D7D7` | `843D` | `6861` | `00` |

## What this demonstrates

1. On real hardware, the read-only controller completed four sequential sector requests, including widely separated 32-bit SDHC block addresses, and produced four `E=00` records plus `SD02 PASS`.
2. RTL simulation separately checked correct CMD17 LBA argument bytes, only one SDHC initialization, a deliberately corrupted CRC16 response and recovery on a subsequent request. [CI record](https://github.com/AIDevelopersMonster/Sipeed-FPGA/actions/runs/40062167278). The CRC fault was **injected in simulation only**: there was no error in the physical UART capture.
3. The hardware design verifies the SD card's transmitted CRC16 and computes another 16-bit CRC from all 512 bytes read back from on-chip RAM for reporting. The reported `CRC` is a digest, not a full data dump.
4. `55AA` at the end of sector 0 is an observed signature, **not** proof of FAT32, a valid partition table, or correct file contents.
5. LBA 1 and 2048 have `H/T/CRC=0000`, **consistent with** all-zero contents, but these three summaries cannot prove the full 512 bytes are zero; a host read-only cross-check or known nonzero patterns are necessary for stronger content validation.
6. The hardware transcript plus RTL evidence supports the limited functional PASS; it does **not** substitute for full electrical I/O timing sign-off, independent bus capture, testing multiple SD-card families, or readback comparison against a PC.

## PnR / STA evidence (reported by operator)

- 812 / 8640 logic (10%); 794 LUT, 18 ALU.
- 301 / 6480 logic flip-flops (5%); BSRAM 4%; DSP 0; PLL 0.
- 27 MHz clock constraint, 37.037 ns period.
- Setup violated endpoints = 0; hold violated endpoints = 0.
- Setup TNS = 0.000 ns; hold TNS = 0.000 ns.
- One listed setup slack = +26.088 ns (not asserted to be the global worst slack).
- No `ERROR`, `FAIL` or `CRITICAL` strings in operator's PnR log filter.
- SD MISO I/O return delay not independently measured or fully constrained.
- Separate [PnR/STA and SRAM programming record](SD02_STA_2026-10-24.md).

## Frozen claims and next research boundary

**Passed:** simulation gate, Gowin build, internal STA, SRAM load and the four-sector physical UART acceptance. **Not established:** a filesystem, FAT32 parser, host-side comparison of all sector bytes, high-speed SPI, hardware-independent reproducibility on a second unit, or PiKoSoL integration.

Preserve this result as an independent educational research snapshot even if a future SoC SD implementation is architecturally different. Next logical study: read-only sector dump/host comparison and MBR/BPB interpretation, then FAT32 directory and file access without modifying existing stored data.

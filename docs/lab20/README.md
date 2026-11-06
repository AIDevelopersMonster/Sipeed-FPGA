# LAB-20 — Tang Nano 20K: LiteX BIOS / VexRiscv

**PiKoSoL · Alex & SoL · Initial hardware acceptance**

- Board: **Sipeed Tang Nano 20K**, PCB marking **V3923** (observed on reverse side).
- FPGA family: **Gowin GW2AR-18**.
- Proven running configuration: **factory LiteX SoC with VexRiscv_Min**, *not* a PiKoSoL-built FPGA image.
- First observed UART console: **COM25**, **115200 8N1** on the tested Windows host. **COM24** also opens; its role has not been positively identified.
- Status: **BOARD PASS (factory LiteX BIOS + SDRAM diagnostic)**. No custom FPGA synthesis, SD boot or user RISC-V application has been verified yet.

## Technical article / Техническая статья

**LiteX BIOS: SoC Early Initialization and the Interactive System Monitor**  
**LiteX BIOS: начальная инициализация SoC и интерактивный системный монитор**

**Publication DOI:** [10.5281/zenodo.23990004](https://doi.org/10.5281/zenodo.23990004)

The technical article has two parts: (I) LiteX BIOS architecture, initialization, memory, serial boot and interactive monitoring in general; (II) the observed configuration and tests on our Tang Nano 20K. Russian and English PDF editions were prepared for publication. The DOI is the canonical publication reference; files in the Zenodo record should be consulted for published versions.

## Further technical papers / Дополнительные публикации

- **VexRiscv / VexRiscv_Min** (RU/EN): [DOI 10.5281/zenodo.23991097](https://doi.org/10.5281/zenodo.23991097). Core architecture and the factory 48 MHz CPU instance on Tang Nano 20K.
- **WISHBONE 32-bit** (RU/EN): [DOI 10.5281/zenodo.23991663](https://doi.org/10.5281/zenodo.23991663). Wishbone B4, handshake, 32-bit data transfers and the reported LiteX 4 GiB address space. The address-space span is not the physical RAM capacity.

## Verified startup evidence / Подтверждённый журнал

The following values come from the **physical board UART session**, after entering `reboot` at the `litex>` prompt:

| BIOS report | Observed value |
| --- | --- |
| BIOS build | Mar 13 2023 17:09:37 |
| BIOS CRC | PASS, `f2b1f4f6` |
| LiteX git SHA prefix | `b05c3069` |
| CPU | `VexRiscv_Min @ 48MHz` |
| Bus | `WISHBONE 32-bit @ 4GiB` |
| CSR | `32-bit data` |
| ROM | 128.0 KiB |
| SRAM | 8.0 KiB |
| L2 | 128 B |
| SDRAM | 8.0 MiB, 32-bit @ 48 MT/s, CL-2 / CWL-2 |
| Main RAM | 8.0 MiB |
| SDRAM initialization | `0x40000000` |
| SDRAM memtest | 2.0 MiB, `0x40000000–0x40200000`, PASS |
| Sequential write | **12.9 MiB/s**, BIOS measurement |
| Sequential read | **16.1 MiB/s**, BIOS measurement |
| Serial boot | Attempted; timeout; `No boot medium found` |
| Interactive monitor | `litex>` available |

**Interpretation:** The CPU executes LiteX BIOS; the memory controller initialized external SDRAM and passed a 2 MiB test. `No boot medium found` means that no eligible application was loaded on this attempt, not that the FPGA failed. `clear` is **not** an available command in this BIOS build.

These read/write speeds are **BIOS-specific measured values**, not the theoretical SDRAM bus peak or a general CPU benchmark. All subsequent bitstreams require independent checks.

## Architecture context / Архитектура

```text
Windows host -- USB-C / board interface -- COM25 (115200 8N1)
                                        |
                                  LiteX BIOS (ROM)
                                        |
                               VexRiscv_Min @ 48 MHz
                                        |
                                Wishbone + CSR
                               /       |       \
                          on-chip    SDRAM    peripherals
                         ROM/SRAM    8 MiB      (to map)
```

This is an explanatory block diagram, **not** a verified netlist or full CSR map. The exact topology, memory windows other than SDRAM base, peripheral mapping, reset behavior and build revisions remain to be recovered from this SoC configuration.

## Next work / Следующие эксперименты

1. Capture the complete response to `litex> help` and inventory commands before issuing memory writes or Flash operations.
2. Record startup console and reset behavior reproducibly; identify COM24/COM25 functions separately.
3. Inspect the accessible ROM/SRAM/SDRAM/CSR address ranges using supported BIOS read-only commands.
4. Prepare a minimal RISC-V application to load into volatile RAM through a validated serial-loader path; preserve factory Flash.
5. Compare the existing VexRiscv/LiteX reference SoC with a separately built PicoRV32-based PiKoSoL system using controlled, comparable benchmarks.

**Safety rule:** Do not overwrite the factory configuration Flash until the restore image and recovery procedure have been independently checked. Prefer reversible SRAM programming and RAM-only payload loading.

## References

- [Publication: LiteX BIOS, RU/EN](https://doi.org/10.5281/zenodo.23990004)
- [LiteX project](https://github.com/enjoy-digital/litex)
- [LiteX BIOS source](https://github.com/enjoy-digital/litex/tree/master/litex/soc/software/bios)
- [VexRiscv](https://github.com/SpinalHDL/VexRiscv)
- [Sipeed Tang Nano 20K documentation](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)

---

**Scope and evidence policy:** “BOARD PASS” applies to the above factory image and observed UART session only. It is not a claim that a newly synthesized PiKoSoL image or any untested peripheral has passed.

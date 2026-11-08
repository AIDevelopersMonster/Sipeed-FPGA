# LAB-20 — Tang Nano 20K: LiteX BIOS / VexRiscv

**PiKoSoL · Alex & SoL · Initial hardware acceptance**

- Board: **Sipeed Tang Nano 20K**, PCB marking **V3923** (observed on reverse side).
- FPGA family: **Gowin GW2AR-18**.
- Proven running configuration: **factory LiteX SoC with VexRiscv_Min**, *not* a PiKoSoL-built FPGA image.
- First observed UART console: **COM25**, **115200 8N1** on the tested Windows host. **COM24** also opens; its role has not been positively identified.
- Status: **BOARD PASS (factory LiteX BIOS + SDRAM diagnostic)**. No custom FPGA synthesis or SD boot has been verified. The user RV32I RAM-only program was **successfully executed on physical hardware** in LAB-20.6.

**Публичная главная страница Tang Nano 20K:** [единый каталог, файлы и инструкции](../../Tang-Nano-20K/README.md) · [как повторить на Windows](../../Tang-Nano-20K/REPRODUCE_LAB20_6_RU.md).


**[Полный справочник BIOS / LiteX, команды и HTML ROM Explorer](../../Tang-Nano-20K/BIOS/LiteX/README.md)** — единая точка входа для повторения всех BIOS-опытов и изучения оригинального кода.

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

## LAB-20.4 — ROM Explorer v3.2 / интерактивный справочник

**Hardware evidence (2026-11-07):** full 128 KiB CPU-visible ROM window acquired read-only from factory LiteX BIOS, SHA-256 `fac8e6e6f39a22e2995de54c271646687d86ad9802e884b848bcf5b6ec4edb65`. Four identical 32 KiB address periods confirmed both by binary comparison and direct LiteX `mem_read`. Canonical unique-period file (32 KiB) SHA-256 `3347be74e9716744949e572229345c3ea9e74f1740001408b934c0d85c79c5bc`; BIOS CRC `f2b1f4f6` matches. Exact post-synthesis BSRAM topology remains unverified.

**[Open ROM Explorer online](rom-explorer/index.html)** · **[Files and reproducibility](rom-explorer/README.md)** · **[32 KiB ROM](rom-explorer/PiKoSoL_LAB20_ROM_32KiB.bin)** · **[ROM alias audit](rom-explorer/ROM_ALIAS_AUDIT.md)**

The standalone HTML is an educational RV32I interpreter and instruction reference with verified board code, memory maps, aliases and step-by-step execution. Its results are software-model tests, **not** a cycle-exact hardware trace. The original 128 KiB dump remains locally archived as primary acquisition evidence.

## LAB-20.5 — CSR and UART initialization (2026-11-07)

The factory BIOS ROM implements a match for LiteX `uart_init()`: `0x000047A4` loads the UART event pending register at **`0xF0003010`**, `0x000047A8` acknowledges pending bits, `0x000047B0` writes 3 to **`0xF0003014`** (TX/RX event enable), and `0x000047B4–0x000047BC` sets bit 0 in VexRiscv-specific machine CSR `0xBC0`. These peripheral registers use `lw/sw` through Wishbone, **not** the RISC-V `csrr*` instruction family. This is a reconstruction from physical ROM + LiteX `b05c3069` sources, not a recording of live event register values.

**[Updated ROM Explorer v3.3 / CSR & UART laboratory](rom-explorer/index.html)** · **[Technical audit and safe BIOS read-only checks](rom-explorer/CSR_UART_LAB20_5.md)**

**New hardware readback, 2026-11-07:** UART CSR values from the live factory BIOS: `txfull=0` at `0xF0003004`, `rxempty=1` at `0xF0003008`, `ev_pending=0` at `0xF0003010`, and `ev_enable=3` at `0xF0003014`. Additional readings: `ev_status(0xF000300C)=1`, `txempty(0xF0003018)=0`, `rxfull(0xF000301C)=0`. `txempty=0` differs from a preliminary idle prediction; the actual measured value is preserved and consistent with a FIFO that is nonempty but not full. These seven reads are separate observations, not a complete dynamic IRQ trace. [Hardware log](rom-explorer/UART_CSR_HARDWARE_2026-11-07.md).

**TX FIFO repeated check:** two further `mem_read 0xF0003018` commands also returned `0`; analysis of LiteX `helpers.c` shows `dump_bytes()` prints its header/address before sampling, which itself may put bytes in TX FIFO. The repeated zeros do **not** prove the FIFO stays nonempty at idle. [Analysis](rom-explorer/UART_CSR_HARDWARE_2026-11-07.md).

## LAB-20.6 — первая самостоятельная программа RV32I в SDRAM

**[Проект и инструкция Windows / COM25](../../03-LiteX-VexRiscv/lab20-6-ram-diag/README.md)** · [Готовый BIN, 740 байт](../../03-LiteX-VexRiscv/lab20-6-ram-diag/snapshot.bin) · [Тестовый отчёт](../../03-LiteX-VexRiscv/lab20-6-ram-diag/TEST_REPORT.md).

Программный снимок TXEMPTY до первого вывода UART и после него: инструкция `boot 0x40010000` заводского LiteX BIOS передаёт управление RV32I+Zicsr-программе в SDRAM, результаты сохранены по `0x40011000` и напечатаны в UART. Размер BIN — 740 байт, 185 машинных слов. **Компиляция и независимый симуляционный тест PASS, физический запуск ещё не подтверждён.** Flash не меняется, для возврата в BIOS необходим аппаратный RESET.

**2026-11-08 hardware milestone:** PiKoSoL LAB-20.6 now has **full 740-byte SDRAM readback PASS** after 185 BIOS `mem_write` operations. PowerShell `-VerifyOnly` read the complete uploaded binary back without additional writes or CPU program launch. This verifies RAM loading, **not** VexRiscv execution. [Hardware receipt](../../03-LiteX-VexRiscv/lab20-6-ram-diag/SDRAM_HARDWARE_PASS_2026-11-08.md). Next gated step: `boot 0x40010000` and capture UART report.

**2026-11-08 LAB-20.6 HARDWARE EXECUTION PASS:** `boot 0x40010000` executed the canonical 740-byte SDRAM image on Tang Nano 20K. Complete MMIO/CSR UART report confirmed `TXEMPTY=1` before own printing and `TXEMPTY=0` after. No CPU IRQ handler delivery proven yet. [Hardware log](../../03-LiteX-VexRiscv/lab20-6-ram-diag/RV32_HARDWARE_EXECUTION_PASS_2026-11-08.md).

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

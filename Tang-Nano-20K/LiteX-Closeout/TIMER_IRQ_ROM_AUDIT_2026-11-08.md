# Factory LiteX ROM: Timer/IRQ forensic map and safe RX ISR test

**Date:** 2026-11-08. **Source:** [32 KiB unique ROM](../BIOS/LiteX/PiKoSoL_LAB20_ROM_32KiB.bin) captured from the *specific factory* Tang Nano 20K board and [LiteX b05c3069 source](https://github.com/enjoy-digital/litex/tree/b05c30690854c462a2e704a22ff895c0055a8265). Reverse-engineering only — not a new hardware test.

## ROM findings (RV32I instructions, CPU-addressed)

| ROM PC | Disassembled instruction / access | Interpretation |
|---|---|---|
| `0x000000C0` | `csrw mtvec, a0` | BIOS installs trap vector |
| `0x0000011C` | `csrw mie, a0` | BIOS configures interrupt sources |
| `0x000017C4` | `csrsi mstatus, 8` | BIOS enables global machine interrupts |
| `0x000045D0` | `lui a5,0xF0003`; `lw a4,16(a5)` | UART pending status |
| `0x00004610` | `lw a5,0x178(a2)`, a2 = `0x10000000` | Reads RX software-ring producer index |
| `0x00004628` | `sw a5,0x178(a2)` | ISR updates producer index (`0x10000178`) |
| `0x00004634` | `sw a7,16(a3)`, a3 = `0xF0003000` | UART RX event acknowledgement |
| `0x00004784` | `sw zero,0x178(a5)`, a5 = `0x10000000` | `uart_init` clears RX producer |
| `0x000047A0-47BC` | UART event pending/enable writes, `csrr/csrw 0xBC0` | BIOS enables UART interrupt source bit 0 |
| `0x00004830-4958` | `0xF0002000+{0,4,8,12,16}` reads/writes | **SDRAM PHY / controller init**, not Timer. ROM strings mention SDRAM initialization/calibration and mode registers |
| `0x00003C84-3D0C` | `0xF0002800+{0,4,8,12,16}` writes/poll | BIOS **timing helper**, likely Timer MMIO, **not proven from generated CSR map**; this region deserves precise source-level identification before any write |

ROM addresses refer to the unique 32-KiB period; virtual ROM larger window repeats the same bytes. Matches LiteX [`libbase/uart.c`](https://github.com/enjoy-digital/litex/blob/b05c30690854c462a2e704a22ff895c0055a8265/litex/soc/software/libbase/uart.c), [VexRiscv `irq.h`](https://github.com/enjoy-digital/litex/blob/b05c30690854c462a2e704a22ff895c0055a8265/litex/soc/cores/cpu/vexriscv/irq.h), and [`system.c` busy_wait](https://github.com/enjoy-digital/litex/blob/b05c30690854c462a2e704a22ff895c0055a8265/litex/soc/software/libbase/system.c).

**Important address correction:** `0xF0002000` is **not** the timer. Do not write to it. The active countdown logic at `0xF0002800` is a **timer candidate**; it is not yet formally identified in the factory generated `csr.h`. Avoid arbitrary peripheral writes until either its source allocation is proven or a guarded testing plan is reviewed.

## Next diagnostic — read-only BIOS RX ISR correlation

[Run `irq_rx_bios_counter.py`](irq_rx_bios_counter.py), importing the already tested `ram_scratch_test.py` serial/hex parser. It reads SRAM `0x10000178` (128-byte ring producer index) through BIOS `mem_read` three times, inserting two known input sequences. The expected differences are **22** and **27** bytes modulo 128. Those counts include the trailing `CR` of each command. Seeing both differences is direct evidence that the factory UART RX ISR updates software state on real hardware. It does **not** isolate the `mret` instruction or prove a new custom trap handler.

This is **no direct RAM or MMIO writes**; BIOS internally necessarily processes UART events, and sending commands may affect the RX ring. No `boot`, no IRQ setup, no FPGA Flash. `--self-test` mock test = 3/3 PASS in the authoring environment; physical `--run` = **BOARD RX ISR PASS 2026-11-08, 22/22 + 27/27** ([квитанция](UART_RX_ISR_BOARD_PASS_2026-11-08.md)). Unknown/failed deltas => `INCONCLUSIVE`, not blanket IRQ failure.

### Commands (PowerShell)

```powershell
git -C C:\GitHub\Sipeed-FPGA fetch origin main
git -C C:\GitHub\Sipeed-FPGA-LAB20-6 switch --detach origin/main
& "C:\GitHub\litex-b05c3069-test\venv\Scripts\python.exe" "C:\GitHub\Sipeed-FPGA-LAB20-6\Tang-Nano-20K\LiteX-Closeout\irq_rx_bios_counter.py" --self-test
& "C:\GitHub\litex-b05c3069-test\venv\Scripts\python.exe" "C:\GitHub\Sipeed-FPGA-LAB20-6\Tang-Nano-20K\LiteX-Closeout\irq_rx_bios_counter.py" --run --port COM25
```

Close browser/terminal holders of COM25 first. If the BIOS prompt is not visible, press the physical board RESET *before* testing. Evidence is written locally as `evidence/IRQ_RX_COUNTER_*.json` (the file content is not automatically uploaded to GitHub).

## Реальная плата: оператор подтвердил RX ISR

2026-11-08 14:24: результаты команд `irq_rx_bios_counter.py --run --port COM25`: **22/22 и 27/27**; [отдельный протокол](UART_RX_ISR_BOARD_PASS_2026-11-08.md). Считать **BOARD PASS корреляции UART RX ISR**, но не пользовательского обработчика trap/mret.

## Уточнение Timer0: по ROM доказана карта регистров, BOARD TEST впереди

Машинные инструкции в настоящем 32-КиБ заводском BIOS ROM: `0x3C84=F0003437` (база `0xF0003000`), `0x3C88=80042423` (запись в `0xF0002808`), `0x3C90=80042223` (запись в `0xF0002804`), `0x3CD4=F00037B7`, `0x3D00=8107A703` (чтение `0xF0002810`). Эта последовательность соответствует `timer0_en_write(0)`, `timer0_reload_write(0)`, `timer0_update_value_write(1)`, `timer0_value_read()` из [`system.c`](https://github.com/enjoy-digital/litex/blob/b05c30690854c462a2e704a22ff895c0055a8265/litex/soc/software/libbase/system.c). Карта CSR таймера выведена из наблюдаемого машинного кода и описания [`timer.py`](https://github.com/enjoy-digital/litex/blob/b05c30690854c462a2e704a22ff895c0055a8265/litex/soc/cores/timer.py); это **сильная идентификация оборудования**, но функциональная проверка Timer0 ещё **не выполнена**. Подготовлен отдельный [`timer0_bios_test.py`](timer0_bios_test.py) с обязательной проверкой fingerprint, backup/restore и ограничением 3 секунды. Не писать по адресам SDRAM контроллера `0xF0002000`.

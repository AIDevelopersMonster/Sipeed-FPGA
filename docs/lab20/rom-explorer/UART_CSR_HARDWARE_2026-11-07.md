# PiKoSoL LAB-20.5 — Hardware UART CSR Readback

**Date:** 2026-11-07 (date of user-supplied terminal capture).  
**Board:** Sipeed Tang Nano 20K, factory LiteX BIOS, VexRiscv_Min @ 48 MHz.  
**Interface:** `litex>` UART monitor, COM25, 115200 8N1.  
**Method:** four single-register `mem_read` calls, 4 bytes each. Read-only: no FPGA Flash, RAM or CSR write.

## Exact capture

```text
litex> mem_read 0xF0003004
Memory dump:
0xf0003004  00 00 00 00                                      ....

litex> mem_read 0xF0003008
Memory dump:
0xf0003008  01 00 00 00                                      ....

litex> mem_read 0xF0003010
Memory dump:
0xf0003010  00 00 00 00                                      ....

litex> mem_read 0xF0003014
Memory dump:
0xf0003014  03 00 00 00                                      ....
```

## Register decoding

| MMIO address | LiteX UART CSR | 32-bit value | Hardware interpretation |
|---|---|---|---|
| 0xF0003004 | `uart_txfull` | 0x00000000 | Transmit FIFO **not full**. Does not prove TX FIFO empty. |
| 0xF0003008 | `uart_rxempty` | 0x00000001 | Receive FIFO **empty at the sampling instant**. |
| 0xF0003010 | `uart_ev_pending` | 0x00000000 | No latched TX/RX event pending at the sampling instant. |
| 0xF0003014 | `uart_ev_enable` | 0x00000003 | Both TX (bit0) and RX (bit1) event masks enabled. |

All values are consistent with LiteX `b05c3069` `UART`/`EventManager` source and with the disassembled `uart_init()` routine in the captured 32 KiB ROM:
`0x47A4 lw a4,16(a5)`, `0x47A8 sw a4,16(a5)`, `0x47B0 sw a4,20(a5)` (with `a4=3`), and IRQ mask operations at `0x47B4–0x47BC`.

**Validation level:** `UART_CSR_READBACK_PASS`, direct evidence for values at these four addresses; the interpretation of register names is corroborated by matching source and firmware. This readback does **not** prove a full CSR map, show complete IRQ timing, or constitute a continuous waveform trace.

## One subtlety: event STATUS is not event PENDING

`uart_ev_status` (predicted at `0xF000300C`) reflects the **current trigger level**.
`uart_ev_pending` (confirmed at `0xF0003010`) reflects **latched events** that have not yet been acknowledged. The two registers need not have the same value. A steady TX-ready status can coexist with pending=0 after acknowledgement.

## Next proposed read-only check

```text
mem_read 0xF000300C
mem_read 0xF0003018
mem_read 0xF000301C
```

Expected register names derived from LiteX `UART` source CSR declaration order: `ev_status`, `txempty`, `rxfull` respectively. Typical idle state: `ev_status` TX-ready bit may be 1, `txempty=1`, `rxfull=0`; values must be **measured**, not assumed. Avoid reading `rxtx` at `0xF0003000` because reads may affect RX behavior. Do not use `mem_write` as a probe.

## Source provenance

- [Historical LiteX UART RTL](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/cores/uart.py)
- [Historical LiteX EventManager](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/interconnect/csr_eventmanager.py)
- [Historical LiteX BIOS uart_init](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/software/libbase/uart.c)
- [LAB-20.5 reconstruction](CSR_UART_LAB20_5.md)

**No hardware reconfiguration or active writes performed.**

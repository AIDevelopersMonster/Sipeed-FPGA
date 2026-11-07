# PiKoSoL LAB-20.5 — Hardware UART CSR Readback

**Date:** 2026-11-07 (date of user-supplied terminal capture).  
**Board:** Sipeed Tang Nano 20K, factory LiteX BIOS, VexRiscv_Min @ 48 MHz.  
**Interface:** `litex>` UART monitor, COM25, 115200 8N1.  
**Method:** nine single-register `mem_read` calls, 4 bytes each (seven distinct CSR addresses and two repeated reads of `txempty`). Read-only: no FPGA Flash, RAM or CSR write.

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

### Follow-up capture: adjacent UART CSR registers

```text
litex> mem_read 0xF000300C
Memory dump:
0xf000300c  01 00 00 00                                      ....

litex> mem_read 0xF0003018
Memory dump:
0xf0003018  00 00 00 00                                      ....

litex> mem_read 0xF000301C
Memory dump:
0xf000301c  00 00 00 00                                      ....
```

## Register decoding

| MMIO address | LiteX UART CSR | 32-bit value | Hardware interpretation |
|---|---|---|---|
| 0xF0003004 | `uart_txfull` | 0x00000000 | Transmit FIFO **not full**. Does not prove TX FIFO empty. |
| 0xF0003008 | `uart_rxempty` | 0x00000001 | Receive FIFO **empty at the sampling instant**. |
| 0xF000300C | `uart_ev_status` | 0x00000001 | TX event trigger level asserted; RX event trigger level inactive. |
| 0xF0003010 | `uart_ev_pending` | 0x00000000 | No latched TX/RX event pending at the sampling instant. |
| 0xF0003014 | `uart_ev_enable` | 0x00000003 | Both TX (bit0) and RX (bit1) event masks enabled. |
| 0xF0003018 | `uart_txempty` | 0x00000000 | TX FIFO was **not empty at the sampling instant**. Different from `txfull`. |
| 0xF000301C | `uart_rxfull` | 0x00000000 | RX FIFO was **not full at the sampling instant**. |

All values are consistent with LiteX `b05c3069` `UART`/`EventManager` source and with the disassembled `uart_init()` routine in the captured 32 KiB ROM:
`0x47A4 lw a4,16(a5)`, `0x47A8 sw a4,16(a5)`, `0x47B0 sw a4,20(a5)` (with `a4=3`), and IRQ mask operations at `0x47B4–0x47BC`.

**Validation level:** `UART_CSR_7_READBACK_PASS`, direct evidence for values at these seven addresses; the interpretation of register names is corroborated by matching source and firmware. This readback does **not** prove a full CSR map, show complete IRQ timing, or constitute a continuous waveform trace.

## One subtlety: event STATUS is not event PENDING

`uart_ev_status` (predicted at `0xF000300C`) reflects the **current trigger level**.
`uart_ev_pending` (confirmed at `0xF0003010`) reflects **latched events** that have not yet been acknowledged. The two registers need not have the same value. A steady TX-ready status can coexist with pending=0 after acknowledgement.

## Why `ev_status=1` while `ev_pending=0`, and `txempty=0`

Verified against LiteX `b05c3069` UART RTL:

```python
self._txfull.status.eq(~tx_fifo.sink.ready)
self._txempty.status.eq(~tx_fifo.source.valid)
self.ev.tx.trigger.eq(tx_fifo.sink.ready)
self._rxempty.status.eq(~rx_fifo.source.valid)
self._rxfull.status.eq(~rx_fifo.sink.ready)
self.ev.rx.trigger.eq(rx_fifo.source.valid)
```

Therefore a non-full TX FIFO (`txfull=0`) asserts TX event status (`ev_status[0]=1`), even when its output still contains a character (`txempty=0`). `ev_pending` is a separate latched event register and may be zero after software acknowledgment. All seven readbacks are **separate moments**, not an atomic concurrent snapshot.

The preliminary expectation `txempty=1` for an idle UART **did not hold**. One plausible explanation is active console output and recently queued characters during `mem_read`; this mechanism was not directly measured and is not presented as an established cause. `txempty=0` refers to FIFO contents, not necessarily whether the serial pin is actively transmitting.

## Next optional diagnostic (read-only; same command repeated)

```text
mem_read 0xF0003018
mem_read 0xF0003018
```

**Performed:** both repeated readings returned zero. Source inspection of `dump_bytes()` demonstrates a self-observation mechanism: the command prints to UART before reading UART TX FIFO status. See 'Third measurement' below. Do not repeat the same procedure as an idle-FIFO diagnostic.

## Completed prior read-only check

```text
mem_read 0xF000300C
mem_read 0xF0003018
mem_read 0xF000301C
```

Predicted register names: `ev_status`, `txempty`, `rxfull`, respectively. Observed values: 1, 0, 0. The earlier anticipated `txempty=1` was incorrect for the observed sampling instant. Avoid reading `rxtx` at `0xF0003000` because reads may affect RX behavior. Do not use `mem_write` as a probe.

## Third measurement: two immediate `txempty` reads

Operator console capture (two additional commands, no writes):

```text
litex> mem_read 0xF0003018
Memory dump:
0xf0003018  00 00 00 00                                      ....

litex> mem_read 0xF0003018
Memory dump:
0xf0003018  00 00 00 00                                      ....
```

Combined with the original reading, **three `txempty=0` readings** were observed.

### Why repeated reads do not test idle-time FIFO vacancy

Investigation of the factory LiteX version (`b05c3069`) found the source-level order of operations:

- `litex/soc/software/bios/cmds/cmd_mem.c`: `mem_read_handler` calls `dump_bytes(addr, length, (unsigned long)addr)`.
- `litex/soc/software/bios/helpers.c`: **`dump_bytes()` prints** `fputs("Memory dump:", stdout);` and then `printf("\\n0x%08lx  ", addr);` **before** the loop that reads the requested address and prints individual byte values via `printf("%02x ", *(unsigned char *)(data+i));`.
- `litex/soc/software/libbase/uart.c`: printing drives UART via `uart_write`.
- `litex/soc/cores/uart.py`: `txempty = ~tx_fifo.source.valid`, meaning queued data sets `txempty=0`.

Thus **the measurement procedure itself can put bytes into the TX FIFO before sampling its occupancy**. Repeating the same command repeats the same output-before-read procedure; repeated zero results cannot distinguish a genuinely always-nonempty FIFO from an otherwise idle FIFO made nonempty by diagnostic output. Print buffering, clock timing, actual queue occupancy and serial-line activity were not instrumented, so this is a **source-backed mechanism consistent with observations, not a cycle-accurate causal proof of each sampled zero**.

**Avoid further repetitive `mem_read 0xF0003018` as a purported idle test.**

For a valid *idle-state* test, use a separately loaded RAM-only instrument that waits for TX FIFO to drain, acquires the CSR value **without printing**, stores the sample in SRAM, and only then prints the stored value (or makes it available to the BIOS dump command). This is proposed work; not executed and not a feature of the existing BIOS command. Preserve factory Flash and verify the RAM-loader path before running it.

**Read-only verification status:** `LAB20_5_TXEMPTY_REPEAT_ZERO / SELF_OBSERVATION_MECHANISM_IDENTIFIED / IDLE_FIFO_STATE_NOT_PROVEN`.

Historical primary source: [LiteX helpers.c `dump_bytes` at b05c3069](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/software/bios/helpers.c).

## Source provenance

- [Historical LiteX UART RTL](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/cores/uart.py)
- [Historical LiteX EventManager](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/interconnect/csr_eventmanager.py)
- [Historical LiteX BIOS uart_init](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/software/libbase/uart.c)
- [LAB-20.5 reconstruction](CSR_UART_LAB20_5.md)

**No hardware reconfiguration or active writes performed.**

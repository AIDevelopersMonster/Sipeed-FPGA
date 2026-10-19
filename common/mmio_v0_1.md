# MMIO contract v0.1 (CPU-independent semantics)

For bootstrapping, map registers at physical base address `0x20000000` (32-bit aligned). All writes/read accesses are little-endian, 32-bit, with byte-strobe semantics as declared by the native bus adapter.

| Offset | Name | Access | Value |
|---|---|---|---|
| `0x00` | `LED` | R/W | lower 6 bits are logical LED ON states; hardware may invert active-low pins |
| `0x04` | `CYCLES` | RO | free-running 32-bit counter in the SoC clock domain, wraps naturally |
| `0x08` | `DEVICE_ID` | RO | `0x5A5A0001` (contract version marker, not silicon ID) |
| `0x0C` | `TEST_STATUS` | R/W | writes `0x600DCAFE` on successful firmware self-test |
| `0x10` | `UART_TX` | WO | transmit least-significant 8 bits; wait until accepted |
| `0x14` | `UART_STATUS` | RO | bit0=1 if UART can accept new byte; all other bits 0 |

This MMIO space is an experiment-level software ABI, not an AXI, Wishbone, or AHB bus definition. Addresses may have to be remapped by CPU/platform adapters; record any deviation.

**Test status ≠ measured PASS.** `0x600DCAFE` is a firmware-generated marker. Only a separate simulator / board log establishes successful execution of the whole system.

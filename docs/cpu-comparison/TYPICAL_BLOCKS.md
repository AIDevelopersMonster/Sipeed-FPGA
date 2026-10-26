# Comparative implementations of typical CPU/SoC blocks / Типовые блоки

**Status:** specification and comparison plan only; no new HDL is claimed as implemented.

This work package compares the following **three** levels for each standard block:

1. **Native implementations**: how PicoRV32/PiKoSoL and NEORV32 architect it, including software/interrupt behavior.
2. **Portable reference implementation**: one defined functional RTL contract, ideally share the **same** module between CPU builds with only bus adapters changed.
3. **Cost of integration**: measured `CPU + adapter + block` minus matched `CPU + adapter` under the exact tool configuration; differences are descriptive, not mathematically additive if synthesis shares logic.

For internal CPU logic the third-party HDL is studied in its original repository, not copied into a new unlicensed core. An **independent educational reference** may be written in Verilog and/or VHDL and tested using the same vectors.

## A. Internal CPU blocks / Внутренние узлы процессора

| Block | Comparable function | Differences to document | Test | Stage |
| --- | --- | --- | --- | --- |
| **ALU32** | 32-bit ADD, SUB, AND, OR, XOR, SLT/SLTU, SLL/SRL/SRA; known overflow behavior in RV32I | Iterative vs parallel shifter, flags, combinational depth, LUT/ALU footprint, implementation language | Identical signed/unsigned/shift corner-case vectors; synthesis for a standalone ALU | 06.3 |
| **Register file** | `x0=0`, 32 × 32-bit registers for RV32I, named address ports | One vs two reads, synchronous/asynchronous read semantics, FF vs BSRAM, read latency | Reset/non-reset behavior, read-after-write, 2-port conflicts, `x0` immutability; report cycle penalty | 06.3 |
| **Decoder / immediate generator** | RV32I R/I/S/B/U/J fields, branch targets, sign extension and illegal opcodes | Combinational vs staged decode, number of control signals, invalid-instruction handling | Fixed 32-bit machine words, incl. S-type `0x01D2A023` and B/J signed offsets | 06.3 |
| **Sequencer / datapath** | Fetch–decode–execute–memory–retire with well-defined exception boundary | Pipeline, iterative states, branch penalty, optional extension handling | Independent trace: PC, instruction, result, memory transaction; count cycles | 06.2/06.3 |
| **Load/store bus** | 32-bit little-endian byte/halfword/word read and write | `mem_valid/mem_ready` vs NEORV32 internal/XBUS; byte strobes; error and misalignment behavior | Randomized wait states, read/write agreement, unaligned-access behavior documented rather than assumed equal | 06.2 |
| **Interrupt/trap path** | Observe event, dispatch/acknowledge and return | PicoRV32 custom IRQ vs NEORV32 machine-mode traps; not binary/ABI equivalent | Separate semantic tests and latency metrics, **not** a single shared ISA test | Optional after 06.2 |

**Important:** NEORV32 is primarily VHDL; using a generated Verilog form must be pinned to the exact upstream commit and GHDL transformation settings. Never attribute a compiler or adapter's overhead to the inherent CPU microarchitecture.

## B. Standard peripherals / Периферия

| Block | Common observable contract / одинаковая функция | PicoRV32 | NEORV32 | Minimal acceptance |
| --- | --- | --- | --- | --- |
| **GPIO6 / LEDs** | Six logical output bits, reset = 0, read-back `00/15/2A/3F`; invert only at physical LED pins | Existing project LED/MMIO or shared GPIO | Native GPIO or same shared GPIO through XBUS adapter | Simulator readback + six real LEDs |
| **UART8N1** | 115200 baud, 8N1, TX/RX, accept/backpressure, errors documented | Existing Verilog UART-8N1 modules / MMIO | Native UART0 and, separately, identical shared UART8N1 block | RX/TX loopback, 256-byte exact sequence, no silent byte loss |
| **TIMER32** | Fabric 27 MHz tick count, free-running wrap and programmed compare/event (if enabled) | New/available counter under common MMIO | Native GPTMR/machine timer plus common shared fabric timer | Monotonic counter and near-wrap test; IRQ as later, separate case |
| **ROM / RAM** | Nominal 16 KiB code + 1 KiB data, byte-lane stores and deterministic initial data | Current independent RTL memory wrapper | NEORV32 IMEM/DMEM or equivalent external memories | Same test image semantics, address map and capacity recorded |
| **SPI mode 0** | 8-bit full-duplex transfers, explicit CS, selectable clock; no SD write during initial comparison | Existing proven SPI RTL | Native NEORV32 SPI host and, separately, common SPI RTL + XBUS adapter | 32 pattern bytes and 512-byte mock; CS/SCK/MOSI/MISO timing simulation |
| **SD sector CMD17** | Read one fixed 512-byte LBA and compare CRC/hash at host | Proven standalone SD-05/SD-06 read path | Same portable SPI/sector engine with adapted CPU bus, or native SPI route separately | Both read the same reserved test card LBA with no writes |
| **HDMI graphics** | Same SVO pipeline clock, one identical display test | Existing PiKoSoL video | Only after CPU fits; same HDMI source and CDC audited | Separate full-system benchmark, **not** a CPU-only comparison |

**Status at programme start:** PicoRV32 LED/UART/HDMI have operator hardware demonstrations, but this does not constitute a matched benchmark. NEORV32 native peripheral behavior is **not yet tested** on our board.

## Bus adapters and common ABI / Адаптеры и адресное пространство

An MMIO contract already exists at [`common/mmio_v0_1.md`](../../common/mmio_v0_1.md):

- `0x20000000` LED output, `+04` CYCLES, `+08` DEVICE_ID, `+0C` TEST_STATUS.
- `+10` UART_TX, `+14` UART_STATUS in the **comparison ABI**.

**Caution:** current PiKoSoL v0.2.0 does **not** implement that comparison ABI byte-for-byte (the existing UART RX/status addresses differ). Never silently change the tested PiKoSoL firmware or claim compatibility. Add new CPU-specific *comparison adapters* in a separate experiment and document native address translation.

For shared peripherals, constrain behavior first, not bus pin names: a CPU-side request, explicit acknowledgement/read result, and decoded byte enables. The **PicoRV32 adapter** uses native memory handshake; the **NEORV32 adapter** uses the selected XBUS/Wishbone-compatible interface, respecting its exact release configuration. The independent block does not know which CPU is connected.

Compare two modes:

- **NATIVE:** built-in NEORV32 peripherals vs existing PicoRV32 external SoC components; honest overall feature/area comparison, not block equality.
- **COMMON-IP:** exact same independent peripheral RTL & test vectors with only the CPU bus adapter different; measure its adapter overhead in addition to total resources.

Do not attempt to convert a native NEORV32 CSR/MMIO register map into PicoRV32's address map by modifying upstream processor internals. Use adapter/wrapper/firmware configuration.

## HDL acceptance contract / Тестовые наборы

- Stable deterministic vectors for each function, including positive and negative cases.
- Testbench report `BLOCK_<NAME>_SIM_PASS` on Icarus or a VHDL-capable simulator; both CPU variants must use equivalent vectors and semantics.
- Physical tests when pins are meaningful; at most three tests in the first bring-up.
- Record exact HDL file hashes, HDL language, native/shared mode, board, tool, constraints, LUT/FF/BSRAM, timing paths and limitations.
- A standalone block that simulates successfully is **not** an integrated SoC block until it is routed and tested with the actual CPU/adapter.
- For SPI/SD initially **read-only**: the separate SD-06 CMD24 scratch-sector pass is not an authorization to write arbitrary files through LAB-06.

**Implementation order / Очерёдность:** GPIO6 + UART8N1 + TIMER32 first; ALU32 + register file + RV32I decoder as independent educational comparison; SPI and SD later. Do not build every block before proving that NEORV32 fits the Tang Nano 9K.

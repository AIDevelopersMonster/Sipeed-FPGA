# NEORV32: Where is the actual VHDL CPU? / Где VHDL-код процессора?

**Answer:** LAB-06.1 synthesized the real upstream **NEORV32** RISC-V CPU plus ROM, RAM, UART0, GPIO6. We **integrated** an existing open-source processor; we did **not** design a new CPU from scratch. A UART print and three LEDs alone would not prove CPU execution. The core sources, GHDL compilation list, RISC-V machine code and Gowin netlist together provide stronger, inspectable evidence.

**Exact upstream commit (BSD-3-Clause):** [`b2620454ebb2407e81a6a1965ef52e2a860b0432`](https://github.com/stnolting/neorv32/tree/b2620454ebb2407e81a6a1965ef52e2a860b0432/rtl/core).

## File map

| Purpose | Actual local Windows path, relative to `C:\GitHub\Sipeed-FPGA` | Clickable pinned source |
|---|---|---|
| Processor CPU top | `02-NEORV32/_deps/neorv32/rtl/core/neorv32_cpu.vhd` | [neorv32_cpu.vhd](https://github.com/stnolting/neorv32/blob/b2620454ebb2407e81a6a1965ef52e2a860b0432/rtl/core/neorv32_cpu.vhd) |
| CPU ALU | `02-NEORV32/_deps/neorv32/rtl/core/neorv32_cpu_alu.vhd` | [neorv32_cpu_alu.vhd](https://github.com/stnolting/neorv32/blob/b2620454ebb2407e81a6a1965ef52e2a860b0432/rtl/core/neorv32_cpu_alu.vhd) |
| Instruction frontend | `02-NEORV32/_deps/neorv32/rtl/core/neorv32_cpu_frontend.vhd` | [neorv32_cpu_frontend.vhd](https://github.com/stnolting/neorv32/blob/b2620454ebb2407e81a6a1965ef52e2a860b0432/rtl/core/neorv32_cpu_frontend.vhd) |
| Decoder/control | `02-NEORV32/_deps/neorv32/rtl/core/neorv32_cpu_control.vhd` | [neorv32_cpu_control.vhd](https://github.com/stnolting/neorv32/blob/b2620454ebb2407e81a6a1965ef52e2a860b0432/rtl/core/neorv32_cpu_control.vhd) |
| Load/store | `02-NEORV32/_deps/neorv32/rtl/core/neorv32_cpu_lsu.vhd` | [neorv32_cpu_lsu.vhd](https://github.com/stnolting/neorv32/blob/b2620454ebb2407e81a6a1965ef52e2a860b0432/rtl/core/neorv32_cpu_lsu.vhd) |
| Register file | `02-NEORV32/_deps/neorv32/rtl/core/neorv32_cpu_regfile.vhd` | [neorv32_cpu_regfile.vhd](https://github.com/stnolting/neorv32/blob/b2620454ebb2407e81a6a1965ef52e2a860b0432/rtl/core/neorv32_cpu_regfile.vhd) |
| Native SoC top | `02-NEORV32/_deps/neorv32/rtl/core/neorv32_top.vhd` | [neorv32_top.vhd](https://github.com/stnolting/neorv32/blob/b2620454ebb2407e81a6a1965ef52e2a860b0432/rtl/core/neorv32_top.vhd) |
| Complex connects CPU | `02-NEORV32/_deps/neorv32/rtl/core/neorv32_core_complex.vhd` | [neorv32_core_complex.vhd](https://github.com/stnolting/neorv32/blob/b2620454ebb2407e81a6a1965ef52e2a860b0432/rtl/core/neorv32_core_complex.vhd) |
| Our LAB-06 wrapper | `02-NEORV32/rtl/lab061_neorv32_top.vhd` | [lab061_neorv32_top.vhd](../rtl/lab061_neorv32_top.vhd) |
| All upstream VHDL files used | `02-NEORV32/_deps/neorv32/rtl/file_list_core.f` | [file_list_core.f](https://github.com/stnolting/neorv32/blob/b2620454ebb2407e81a6a1965ef52e2a860b0432/rtl/file_list_core.f) |

**Why no VHDL CPU tree in our GitHub?** The project deliberately ignores `02-NEORV32/_deps/`, preserving a clean checkout of the pinned upstream repository instead of copying it to our Git history. Run `02-NEORV32/tools/preflight.ps1` to check its revision. `README.md` and `rtl/lab061_neorv32_top.vhd` are our integration sources, not replacements for the core.

## Actual instantiated hierarchy

```text
lab061_neorv32_top.vhd (our board-level VHDL wrapper)
└── u_cpu: neorv32_top  [our wrapper, generic map]
    └── core_complex_inst: neorv32_core_complex  [upstream top]
        └── cpu_inst: neorv32_cpu  [upstream actual RV32I CPU]
            ├── instruction frontend + decoder/control
            ├── ALU + shifter
            ├── load/store unit
            └── 32-register file  (CPU_RF_ARCH_SEL => 2, registers)
```

In our wrapper: `BOOT_MODE_SELECT => 2`, `IMEM_EN => true` (16KiB), `DMEM_EN => true` (2KiB), `IO_UART0_EN => true`, `IO_GPIO_NUM => 6`. The string `NEORV32 READY` is part of **compiled RISC-V firmware**, not a UART state machine written into the board RTL wrapper.

## One-minute verification in PowerShell 7 (read-only)

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
$Core = '.\02-NEORV32\_deps\neorv32\rtl\core'

git -C .\02-NEORV32\_deps\neorv32 rev-parse HEAD
Get-ChildItem $Core -Filter 'neorv32_cpu*.vhd' -File |
    Select-Object Name,Length

Select-String -Path (Join-Path $Core 'neorv32_cpu.vhd') -Pattern 'entity neorv32_cpu is'
Select-String -Path (Join-Path $Core 'neorv32_core_complex.vhd') -Pattern 'cpu_inst: entity neorv32.neorv32_cpu'
Select-String -Path '.\02-NEORV32\rtl\lab061_neorv32_top.vhd' -Pattern 'u_cpu: neorv32_top'
```

**To verify that there is real machine code rather than an RTL UART banner**, disassemble the exact firmware used for the accepted SIM image:

```powershell
.\02-NEORV32\tools\activate_ucrt64.ps1

$Elf = '.\02-NEORV32\_build\run_20261026_142450_892\lab061.elf'
& riscv64-unknown-elf-objdump -d $Elf

$PnrLog = '.\02-NEORV32\_build\fit_20261026_144630_744_c86f33\gowin_cli.log'
Select-String $PnrLog -Pattern 'Compiling module .neorv32_cpu_', 'neorv32_cpu_frontend', 'neorv32_cpu_alu', 'neorv32_cpu_lsu', 'neorv32_cpu_regfile'
```

The `objdump` output should contain genuine RISC-V instructions (loads/stores, branches, register operations). The Gowin log should contain synthesis of CPU hierarchy; in the accepted build the physical board sent `NEORV32 READY` and the operator observed three lit LEDs. These are independent evidence layers but **not** a full instruction-set compliance suite or a cycle benchmark.

**Important distinction for LAB-06.2:** PicoRV32 is written in **Verilog**, not VHDL. Its actual CPU source is `01-PicoRV32/vendor/picorv32/picorv32.v` at pinned SHA `ef203c2b0a3fb793280f5114941416c425c5b461`, linked to the project via [the LAB-06.2 wrapper](../../01-PicoRV32/lab06/rtl/lab062_pico_soc.v). The new LAB-06.2 experiment has **not** yet passed the re-run simulation and has **no new verified hardware fit**. Do not conflate this with already hardware-accepted PiKoSoL/PicoRV32 builds.

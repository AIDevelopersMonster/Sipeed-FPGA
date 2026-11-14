#!/usr/bin/env bash
# No JTAG, Flash, SDRAM writes, serial port or FPGA programming is performed.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${CLANG:=clang}"
: "${LLD:=ld.lld}"
: "${OBJCOPY:=llvm-objcopy}"
: "${OBJDUMP:=llvm-objdump}"
if [[ $# -ne 1 || ! "$1" =~ ^0[xX][0-9a-fA-F]{8}$ ]]; then
  echo 'Usage: tools/build_rv32.sh 0xF0003000 (UART base MUST be verified in EX20-05.16 csr.csv)' >&2
  exit 2
fi
mkdir -p build
flags=(--target=riscv32-unknown-elf -march=rv32i_zicsr -mabi=ilp32 -mno-relax -msmall-data-limit=0 -ffreestanding -fno-builtin -fno-pic -fno-stack-protector -fno-unwind-tables -fno-asynchronous-unwind-tables -Os -std=c99 -Wall -Wextra -Werror -DPIKOSOL_UART_BASE="$1")
"$CLANG" "${flags[@]}" -c firmware/pikosol_shell.c -o build/pikosol_shell.o
"$CLANG" "${flags[@]}" -c firmware/platform_litex.c -o build/platform_litex.o
"$CLANG" "${flags[@]}" -c firmware/runtime.c -o build/runtime.o
"$CLANG" "${flags[@]}" -c firmware/start.S -o build/start.o
"$LLD" -m elf32lriscv -T firmware/linker.ld --no-relax --build-id=none -nostdlib -Map=build/pikosol20k.map build/start.o build/platform_litex.o build/pikosol_shell.o build/runtime.o -o build/pikosol20k.elf
"$OBJCOPY" -O binary build/pikosol20k.elf build/pikosol20k.bin
"$OBJDUMP" -d build/pikosol20k.elf > build/pikosol20k.disasm.txt
python3 tools/image_to_memwrites.py build/pikosol20k.bin build/load_mem_write_only.txt
python3 tools/write_build_manifest.py build/pikosol20k.bin "$1" build/pikosol20k_build.json
sha256sum build/pikosol20k.bin | tee build/pikosol20k.sha256
printf 'RV32I BUILD PASS (software build only); DO NOT BOOT until map and full readback verified.\n'

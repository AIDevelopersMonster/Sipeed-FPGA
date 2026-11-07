#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
: "${CLANG:=clang}"
: "${LLD:=ld.lld}"
: "${OBJCOPY:=llvm-objcopy}"
: "${OBJDUMP:=llvm-objdump}"
"$CLANG" --target=riscv32-unknown-elf -march=rv32i_zicsr -mabi=ilp32 -mno-relax -c snapshot.S -o snapshot.o
"$LLD" -m elf32lriscv -T linker.ld -nostdlib --build-id=none snapshot.o -o snapshot.elf
"$OBJCOPY" -O binary snapshot.elf snapshot.bin
"$OBJDUMP" -d -M no-aliases snapshot.elf > snapshot.disasm.txt
python3 generate_commands.py
python3 test_emulator.py
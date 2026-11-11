#!/usr/bin/env python3
"""Patch upstream nano-Z80 ROM Monitor to support U: UART CP/Mish boot.

Source reference: venomix666/nano-z80 @ 0e2692ad10da8cbc0351758fea0fffa2dcf30110
No FPGA/Flash/SD writes. Explicit --apply is required.
"""
import argparse
import hashlib
from pathlib import Path

DECODER_OLD = "        cp 'B'\n        jp z, monitor_boot\n        cp 'L'"
DECODER_NEW = "        cp 'B'\n        jp z, monitor_boot\n        cp 'U'\n        jp z, monitor_boot_uart\n        cp 'L'"
HANDLER_OLD = "monitor_sd_load:\n        call sd_boot\n        ret"
HANDLER_NEW = """; Boot tested CP/Mish 2.2r0 via UART A (verified COM25).
monitor_boot_uart:
        di
        ld a, IO_SELECT_PIC
        out (IO_BANK), a
        xor a
        out (PIC_IRQ_ENABLE), a
        ld (BOOT_PAGE), a      ; invalidate stale boot address
        call sd_boot

        ld a, (BOOT_PAGE)
        cp $F6                ; require known CP/Mish BIOS address
        jr nz, monitor_boot_uart_error
        ld hl, $F633
        ld a, (hl)
        cp $81                ; unmodified IOBYTE
        jr z, monitor_boot_uart_patch
        cp $83                ; already set to UART
        jr nz, monitor_boot_uart_error
monitor_boot_uart_patch:
        ld (hl), $83
        jp $F600
monitor_boot_uart_error:
        ld hl, msg_uart_boot_error
        jp print_string

monitor_sd_load:
        call sd_boot
        ret"""
HELP_OLD = '        db "B           - boot CP/M from the SD card", 13, 10\n        db "L'
HELP_NEW = ('        db "B           - boot CP/M from the SD card", 13, 10\n'
            '        db "U           - boot CP/Mish via UART A", 13, 10\n        db "L')
ERROR_OLD = 'msg_ready:\n        db "Ready",13,10,0'
ERROR_NEW = ('msg_uart_boot_error:\n'
             '        db "U failed: expected CP/Mish F600 / IOBYTE F633",13,10,0\n'
             'msg_ready:\n        db "Ready",13,10,0')
PATCHES = [
    ("decoder", DECODER_OLD, DECODER_NEW),
    ("handler", HANDLER_OLD, HANDLER_NEW),
    ("help", HELP_OLD, HELP_NEW),
    ("error", ERROR_OLD, ERROR_NEW),
]

def patch_source(source):
    if "monitor_boot_uart:" in source:
        raise ValueError("Already patched; refusing to patch twice")
    for name, old, new in PATCHES:
        if source.count(old) != 1:
            raise ValueError(f"{name}: unexpected upstream source, refusing to patch")
        source = source.replace(old, new, 1)
    return source

def main():
    parser = argparse.ArgumentParser(description="Guarded nano-Z80 U command source patch")
    parser.add_argument("source", type=Path, help="Upstream romcode/nano-z80.z80")
    parser.add_argument("--apply", action="store_true", help="Back up and modify the original source")
    args = parser.parse_args()
    if args.source.name != "nano-z80.z80":
        parser.error("Expected a file named nano-z80.z80")
    original = args.source.read_bytes()
    patched = patch_source(original.decode("utf-8")).encode("utf-8")
    print("SOURCE_PATCH_CHECK_PASS")
    print("BEFORE_SHA256=" + hashlib.sha256(original).hexdigest().upper())
    print("AFTER_SHA256=" + hashlib.sha256(patched).hexdigest().upper())
    if not args.apply:
        print("DRY_RUN: no files changed; use --apply to modify source")
        return
    backup = args.source.with_suffix(".z80.pre-u.bak")
    if backup.exists():
        parser.error(f"Backup exists: {backup}")
    backup.write_bytes(original)
    try:
        args.source.write_bytes(patched)
    except BaseException:
        args.source.write_bytes(original)
        raise
    print("SOURCE_PATCH_APPLIED")
    print("BACKUP=" + str(backup))
    print("Next: build ROM with zasm, then Gowin bitstream. SRAM only.")

if __name__ == "__main__":
    main()

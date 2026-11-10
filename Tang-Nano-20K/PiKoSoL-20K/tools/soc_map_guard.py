#!/usr/bin/env python3
"""Fail-closed EX20-05.16 address-map preflight. Offline, no UART.

Do not treat the CSV as evidence of the *running* FPGA: V201 signature
and operator bitstream provenance are separately required at the board gate.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path

VIDEO_BASE = 0xB1000000
VIDEO_SPAN = 0x100
ENTRY = 0x40010000
STACK_END = 0x40020000
UART_OFFSETS = {"uart_rxtx": 0, "uart_txfull": 4, "uart_rxempty": 8}

class MapGuardError(ValueError):
    pass


def _integer(raw: str) -> int:
    try:
        if not raw.strip():
            raise ValueError("empty")
        return int(raw.strip(), 0)
    except (TypeError, ValueError) as exc:
        raise MapGuardError(f"invalid map integer {raw!r}") from exc


def parse_map(csv_path: Path) -> dict:
    content = csv_path.read_bytes()
    rows = list(csv.reader(content.decode("utf-8-sig").splitlines()))
    bases, regs, regions = {}, {}, {}
    for row in rows:
        if not row or row[0].lstrip().startswith('#'):
            continue
        if len(row) < 3:
            continue
        kind, name, value = (row[0].strip().lower(), row[1].strip().lower(), row[2].strip())
        if kind in {"csr_base", "csr_register", "memory_region"}:
            group = bases if kind == "csr_base" else regs if kind == "csr_register" else regions
            if name in group:
                raise MapGuardError(f"duplicate {kind} {name}: ambiguous SoC map")
            addr = _integer(value)
            if kind == "memory_region":
                if len(row) < 4:
                    raise MapGuardError(f"missing length for memory region {name}")
                size = _integer(row[3])
                if size <= 0 or addr + size > 0x100000000:
                    raise MapGuardError(f"invalid memory region bounds {name}")
                group[name] = (addr, size)
            else:
                group[name] = addr
    return {"sha256": hashlib.sha256(content).hexdigest(), "csr_bases": bases,
            "registers": regs, "regions": regions}


def certify(csv_path: Path) -> dict:
    m = parse_map(csv_path)
    bases, regs, regions = m["csr_bases"], m["registers"], m["regions"]
    if "uart" not in bases:
        raise MapGuardError("missing csr_base,uart: cannot assume factory UART mapping")
    uart = bases["uart"]
    if uart % 4:
        raise MapGuardError("unaligned UART base")
    for name, off in UART_OFFSETS.items():
        addr = regs.get(name)
        if addr != uart + off:
            raise MapGuardError(f"{name}: expected 0x{uart+off:08X}, CSV has {addr!r}")
    if "video" not in regions or regions["video"] != (VIDEO_BASE, VIDEO_SPAN):
        raise MapGuardError(f"V201 region must be exactly 0x{VIDEO_BASE:08X}/0x{VIDEO_SPAN:X}")
    ram_candidates = [(n, origin, size) for n, (origin, size) in regions.items()
                      if n in {"main_ram", "sdram"}]
    valid_ram = [(n, a, s) for n, a, s in ram_candidates
                 if a <= ENTRY and a + s >= STACK_END]
    if len(valid_ram) != 1:
        raise MapGuardError("exactly one declared main_ram/sdram region must contain code and stack")
    ram_name, ram_start, ram_size = valid_ram[0]
    for name, (origin, size) in regions.items():
        if name in {ram_name, "video"}:
            continue
        if not (origin + size <= ENTRY or origin >= STACK_END):
            raise MapGuardError(f"region {name} overlaps application SDRAM window")
    return {"status": "MAP_STRUCTURE_PASS_NOT_BOARD_PASS",
            "csv_sha256": m["sha256"], "uart_base": uart,
            "uart_registers": {name: regs[name] for name in UART_OFFSETS},
            "video_base": VIDEO_BASE, "video_size": VIDEO_SPAN,
            "ram_name": ram_name, "ram_origin": ram_start,
            "ram_size": ram_size, "entry": ENTRY, "stack_end": STACK_END}


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("csr_csv", type=Path, help="actual EX20-05.16 build/csr.csv")
    ap.add_argument("--output", type=Path, help="write an offline JSON receipt")
    args = ap.parse_args()
    try:
        result = certify(args.csr_csv)
    except (MapGuardError, OSError, UnicodeError) as exc:
        ap.exit(2, f"MAP GUARD STOP: {exc}\n")
    print(json.dumps(result, indent=2))
    print("MAP STRUCTURE PASS ONLY. Verify running V201 ID; do not assume CSV identifies board bitstream.")
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")


if __name__ == "__main__":
    main()

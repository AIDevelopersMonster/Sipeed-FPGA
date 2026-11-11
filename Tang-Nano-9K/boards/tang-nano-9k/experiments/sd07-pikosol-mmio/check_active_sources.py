#!/usr/bin/env python3
"""SD07 read-only, scoped SHA256 gate for inputs actually used in its Gowin fit.

The historical LAB04 package-wide manifest can diverge for *unused* old SDC
or documentation. Do not alter the hardware-accepted LAB04 tree/manifest.
Do not silently whitelist any mismatched source that the SD07 fit consumes.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
LAB = ROOT / "01-PicoRV32" / "lab04"
SUMS = LAB / "SHA256SUMS.txt"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run() -> int:
    if not SUMS.is_file():
        raise ValueError(f"Missing baseline SHA manifest: {SUMS}")
    records: dict[str, str] = {}
    for line in SUMS.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        m = re.fullmatch(r"([0-9a-f]{64})  ([A-Za-z0-9_./-]+)", line)
        if m is None or m[2] in records or ".." in Path(m[2]).parts:
            raise ValueError(f"Malformed/duplicate manifest line: {line!r}")
        records[m[2]] = m[1]

    # Files actually staged by fit.ps1 from the qualified LAB04 source tree.
    active = {
        f.relative_to(LAB).as_posix()
        for f in (LAB / "rtl").glob("*.v")
    }
    active.update(
        f.relative_to(LAB).as_posix()
        for f in (LAB / "rtl").glob("*.hex")
    )
    active.update({
        "firmware/lab04_boot.hex",
        "firmware/lab04_rom_meta.json",
        "firmware/lab04_boot.S",
        "constraints/lab04_cpu_video_v018b.sdc",
        "tools/build_rom.py",
        "tools/check_sta_v018b.py",
    })
    if len(active) < 14:
        raise ValueError(f"Suspiciously small LAB04 source set: {len(active)}")
    for name in sorted(active):
        if name not in records:
            raise ValueError(f"Unlisted active source (no trustworthy SHA): {name}")
        path = LAB / name
        if not path.is_file():
            raise ValueError(f"Missing active source: {name}")
        actual = digest(path)
        if actual != records[name]:
            raise ValueError(
                f"ACTIVE SOURCE SHA256 MISMATCH: {name}\n"
                f"expected {records[name]}\nactual   {actual}"
            )

    # Diagnose, don't mask: an unrelated archived SDC/document mismatch does
    # not change the contents synthesized by this isolated integration test.
    ignored_diffs = []
    for name, expected in sorted(records.items()):
        if name in active:
            continue
        path = LAB / name
        if not path.is_file():
            ignored_diffs.append(f"missing: {name}")
        elif digest(path) != expected:
            ignored_diffs.append(f"digest differs: {name}")
    for issue in ignored_diffs:
        print(f"LAB04_UNUSED_BASELINE_DIFFERENCE: {issue}")
    print(
        f"SD07_ACTIVE_SOURCE_SHA256_PASS: {len(active)} actual LAB04 inputs "
        f"matched original manifest; {len(ignored_diffs)} unused historical differences"
    )
    print("SD07_ACTIVE_SOURCE_SCOPE: no modification of LAB04 sources or SHA256SUMS.txt")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(run())
    except (OSError, ValueError, UnicodeError) as e:
        print(f"SD07_ACTIVE_SOURCE_SHA256_FAIL: {e}", file=sys.stderr)
        raise SystemExit(1)

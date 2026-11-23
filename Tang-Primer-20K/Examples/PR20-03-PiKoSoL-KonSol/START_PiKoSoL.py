#!/usr/bin/env python3
# PiKoSoL TP20: GitHub ZIP -> SRAM firmware -> UART monitor -> File Manager.
# PC-side launcher; no FPGA Flash operations. Hardware route needs operator test.
from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
HOST = ROOT / "tools" / "host_console.py"
MONITOR = ROOT / "firmware" / "monitor.bin"
DEMO = ROOT / "firmware" / "demo.bin"
GUI = ROOT / "FileManager" / "PiKoSoL_FileManager.py"
BITSTREAM = ROOT / "firmware" / "PiKoSoL_TP20_SD01_RO.fs"

MONITOR_SHA256 = "414D8B9859CE95826E9A0BA12A26E820AF2942CD4FD964EA9FF75AC28AE135C7"
DEMO_SHA256 = "BE20FB6EC6D1C7BFE1E9591F0C734649C61D200217F5EBF15800B4F4E681DE26"
BITSTREAM_SIZE = 7264150
BITSTREAM_SHA256 = "900C95DC8575C31EBD3E01F61A64F99A8BBA14358A0C0DB20110140B27C89D28"
DEFAULT_PROGRAMMER = Path(
    r"C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe"
)


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fp:
        for chunk in iter(lambda: fp.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest().upper()


def assert_file(path: Path) -> None:
    if not path.is_file():
        raise RuntimeError(f"Missing file in GitHub ZIP: {path}")


def verify_baseline() -> None:
    for file in (HOST, MONITOR, DEMO, GUI, ROOT / "FileManager" / "pikosol_core.py"):
        assert_file(file)
    for path, expected in ((MONITOR, MONITOR_SHA256), (DEMO, DEMO_SHA256)):
        actual = sha256_file(path)
        if actual != expected:
            raise RuntimeError(
                f"{path.name}: SHA256 mismatch. Expected {expected}, found {actual}.\n"
                "Do not overwrite files; download a clean GitHub ZIP."
            )
        print(f"SHA256 PASS: {path.name} ({path.stat().st_size} bytes)")
    subprocess.run(
        [sys.executable, "-B", str(GUI), "--root", str(ROOT), "--check"],
        cwd=str(ROOT), check=True
    )
    print("MONITOR/GUI PREFLIGHT PASS; no COM port or FPGA was accessed.")


def verify_bitstream(path: Path) -> None:
    if not path.is_file():
        raise RuntimeError(f"FPGA firmware not found: {path}")
    actual_size = path.stat().st_size
    if actual_size != BITSTREAM_SIZE:
        raise RuntimeError(
            f"FPGA firmware size mismatch: {actual_size}, expected {BITSTREAM_SIZE}: {path}"
        )
    actual_sha256 = sha256_file(path)
    if actual_sha256 != BITSTREAM_SHA256:
        raise RuntimeError(
            f"FPGA firmware SHA256 mismatch: expected {BITSTREAM_SHA256}, "
            f"found {actual_sha256}: {path}"
        )
    print(f"FPGA firmware SHA256 PASS: {path.name} ({actual_size} bytes)")


def ensure_bitstream() -> Path:
    verify_bitstream(BITSTREAM)
    return BITSTREAM


def get_programmer(explicit: str) -> Path:
    raw = explicit or os.environ.get("GOWIN_PROGRAMMER", "")
    if raw:
        candidate = Path(raw.strip('" '))
    else:
        found = shutil.which("programmer_cli.exe")
        candidate = Path(found) if found else DEFAULT_PROGRAMMER
    if not candidate.is_file() and sys.stdin.isatty():
        print(f"Gowin Programmer not found: {candidate}")
        typed = input("Full path to programmer_cli.exe: ").strip().strip('"')
        if typed:
            candidate = Path(typed)
    if not candidate.is_file():
        raise RuntimeError(
            f"Missing Gowin Programmer: {candidate}\n"
            "Use --programmer \"C:\\path\\to\\programmer_cli.exe\""
        )
    return candidate


def require_host_dependencies() -> None:
    try:
        import tkinter  # noqa: F401
        import serial  # type: ignore[import-not-found]  # noqa: F401
    except ImportError as exc:
        raise RuntimeError(
            f"Python dependency missing: {exc}. Install pyserial with:\n"
            f'"{sys.executable}" -m pip install pyserial\n'
            "Tkinter must be included with your Python installation."
        ) from exc


def select_port(explicit: str) -> str:
    port = explicit.strip().upper()
    if not port:
        if not sys.stdin.isatty():
            raise RuntimeError("Pass --port COM10 in noninteractive mode.")
        typed = input("Dock UART COM port [COM10]: ").strip().upper()
        port = typed or "COM10"
    if not re.fullmatch(r"COM[1-9][0-9]*", port):
        raise RuntimeError(f"Invalid Windows COM port: {port}")
    return port


def select_mode(explicit: str) -> str:
    if explicit != "ask":
        return explicit
    print("")
    print("Choose the action (all firmware programming is SRAM ONLY):")
    print("  1. Full start: program PiKoSoL SD01 RO .fs (SRAM), load monitor, open GUI")
    print("  2. FPGA already at 'Waiting for downloader': load monitor, open GUI")
    print("  3. PiKoSoL> monitor already running: open GUI only")
    print("CAUTION: option 1 replaces any CURRENT volatile FPGA configuration,")
    print("including experimental DDR3 builds. External Flash is never written.")
    if not sys.stdin.isatty():
        raise RuntimeError("Pass --mode program|boot|gui in noninteractive mode.")
    value = input("Mode [1]: ").strip() or "1"
    modes = {"1": "program", "2": "boot", "3": "gui"}
    if value not in modes:
        raise RuntimeError(f"Unknown mode: {value}")
    return modes[value]


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Start GitHub PiKoSoL TP20 from extracted ZIP; SRAM only."
    )
    ap.add_argument("--check", action="store_true", help="Offline integrity check only")
    ap.add_argument("--port", default="", help="Dock UART, e.g. COM10 (default: ask)")
    ap.add_argument(
        "--mode", choices=("ask", "program", "boot", "gui"), default="ask",
        help="program=FPGA+monitor, boot=monitor only, gui=File Manager only"
    )
    ap.add_argument("--programmer", default="", help="Path to Gowin programmer_cli.exe")
    args = ap.parse_args()

    print("PiKoSoL TP20 / GitHub startup / SRAM ONLY / NO FLASH")
    print("FOLDER:", ROOT)
    verify_baseline()
    if args.check:
        ensure_bitstream()
        return 0

    require_host_dependencies()
    port = select_port(args.port)
    mode = select_mode(args.mode)
    if mode == "program":
        fs = ensure_bitstream()
        programmer = get_programmer(args.programmer)
        print(f"FPGA SRAM PROGRAM: {programmer} --device GW2A-18C --run 2 --fsFile {fs}")
        subprocess.run(
            [str(programmer), "--device", "GW2A-18C", "--run", "2", "--fsFile", str(fs)],
            cwd=str(ROOT), check=True
        )
        print("FPGA SRAM PROGRAM CLI PASS; monitor still needs verification.")

    if mode in ("program", "boot"):
        print("Close MobaXterm and other COM clients before XMODEM.")
        print("IMPORTANT: wait for 'COM OPEN PASS', then press Dock S0 ONCE.")
        print("The loader will keep COM open until C arrives (Ctrl+C cancels).")
        subprocess.run(
            [
                sys.executable, "-B", str(HOST),
                "--port", port, "--baud", "115200",
                "--monitor", str(MONITOR), "--demo", str(DEMO),
                "--boot-only", "--wait-for-s0",
            ],
            cwd=str(ROOT), check=True
        )
        print("MONITOR BOOT CONFIRMED; UART released for File Manager.")

    print(f"COM released by monitor uploader. Opening File Manager on {port}.")
    subprocess.run(
        [sys.executable, "-B", str(GUI), "--root", str(ROOT), "--port", port],
        cwd=str(ROOT), check=True
    )
    print("File Manager closed. No FPGA Flash modifications.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, subprocess.CalledProcessError) as exc:
        print(f"START FAILED: {exc}", file=sys.stderr)
        print("STOP. No FPGA Flash write was requested.", file=sys.stderr)
        raise SystemExit(2)

#!/usr/bin/env python3
"""Capture an exact read-only SD-04 ROOT-sector UART frame after board reset.

The FPGA transmits once after reset: open this tool FIRST, then press S2.
Requires pyserial only for the live COM port; the frame validator needs no
third-party dependency. Does not write any data to the SD card.
"""
import argparse
import hashlib
import pathlib
import sys
import time
from datetime import datetime
from sd04_decode import decode_entries


def validate_frame(raw):
    """Fail closed: no partial frames, extra bytes or invented sector content."""
    if raw == b"ERROR\r\n":
        raise ValueError("FPGA reported ERROR (scanner or CMD17 failed)")
    if not raw.endswith(b"\r\n"):
        raise ValueError("expected CRLF at end of UART frame")
    payload = raw[:-2]
    if len(payload) != 1024:
        raise ValueError(
            f"incomplete UART frame: got {len(payload)} HEX characters, "
            "expected 1024; open COM before resetting FPGA"
        )
    if any(byte not in b"0123456789ABCDEF" for byte in payload):
        raise ValueError("UART frame contains non-uppercase-HEX characters")
    return bytes.fromhex(payload.decode("ascii"))


def receive_frame(ser, timeout_seconds):
    """Read from an already open serial port, preserving all received bytes."""
    deadline = time.monotonic() + timeout_seconds
    raw = bytearray()
    while time.monotonic() < deadline:
        count = max(1, int(ser.in_waiting))
        fragment = ser.read(count)
        if not fragment:
            continue
        raw.extend(fragment)
        if len(raw) > 2048:
            raise ValueError("UART frame exceeds 2048 bytes; wrong port/baud?")
        if b"\n" in raw:
            if raw[-1] != 10 or raw.count(10) != 1:
                raise ValueError("unexpected extra data or multiple lines")
            return validate_frame(bytes(raw))
    raise TimeoutError(
        f"UART timeout after {timeout_seconds:g}s; "
        "check port and press the board S2 reset after PORT_OPEN"
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--port", help="the board's UART COM port, e.g. COM5")
    group.add_argument("--list-ports", action="store_true", help="enumerate UART ports")
    parser.add_argument("--timeout", type=float, default=60.0)
    parser.add_argument("--out-dir", type=pathlib.Path,
                        help="capture output folder; default experiment/build/capture_<timestamp>")
    args = parser.parse_args()
    try:
        import serial
        from serial.tools import list_ports
    except ImportError:
        print("SD04_CAPTURE_ERROR: pyserial missing; install: python -m pip install pyserial",
              file=sys.stderr)
        return 2

    if args.list_ports:
        ports = list(list_ports.comports())
        for item in ports:
            print(f"{item.device}: {item.description}")
        if not ports:
            print("No serial COM ports found")
        return 0
    if args.timeout <= 0 or args.timeout > 300:
        parser.error("--timeout must be in (0, 300] seconds")

    try:
        with serial.Serial(args.port, baudrate=115200, bytesize=8,
                           parity="N", stopbits=1, timeout=0.25,
                           xonxoff=False, rtscts=False, dsrdtr=False) as ser:
            ser.reset_input_buffer()
            print(f"SD04_PORT_OPEN: {args.port} 115200 8N1", flush=True)
            print("NOW PRESS BOARD S2 RESET while this command is running.", flush=True)
            sector = receive_frame(ser, args.timeout)
    except (OSError, ValueError, TimeoutError, serial.SerialException) as exc:
        print(f"SD04_CAPTURE_FAIL: {exc}", file=sys.stderr)
        return 1

    out_dir = args.out_dir or (
        pathlib.Path(__file__).resolve().parents[1] / "build" /
        ("capture_" + datetime.now().strftime("%Y%m%d_%H%M%S"))
    )
    out_dir.mkdir(parents=True, exist_ok=True)
    root_hex = out_dir / "root.hex"
    root_bin = out_dir / "root.bin"
    root_hex.write_bytes(sector.hex().upper().encode("ascii") + b"\r\n")
    root_bin.write_bytes(sector)
    digest = hashlib.sha256(sector).hexdigest().upper()
    print("SD04_FRAME_PASS: 1024 HEX characters, 512 bytes, CRLF")
    print(f"SD04_SECTOR_SHA256: {digest}")
    print(f"SD04_HEX_FILE: {root_hex}")
    print(f"SD04_BINARY_FILE: {root_bin}")
    found = False
    for idx, name, attr, cluster, size in decode_entries(sector):
        found = True
        print(f"SD04_ENTRY: {idx:02d} {name} ATTR={attr:02X} "
              f"CLUS={cluster:08X} SIZE={size}")
    if not found:
        print("SD04_NOTE: no short 8.3 entries found in the first sector")
    print("SD04_NOTE: UART frame has no LBA/CRC metadata; host comparison remains pending")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

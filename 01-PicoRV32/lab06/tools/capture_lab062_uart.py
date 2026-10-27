#!/usr/bin/env python3
"""LAB-06.2C UART proof: exact 115200-8N1 PicoRV32 banner from real COM port.

This is a receive-only, bounded capture; S1 must be pressed after opening.
Raw binary is saved before success/failure evaluation. No port writes.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import sys
import time

BANNER = b"PICORV32 READY\r\n"

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--port", default="COM10")
    p.add_argument("--seconds", type=int, default=25)
    p.add_argument("--raw", type=Path, required=True)
    a = p.parse_args()
    if not 5 <= a.seconds <= 120:
        p.error("seconds must be 5..120")
    try:
        import serial
    except ImportError:
        print("LAB062_PYSERIAL_MISSING: python -m pip install pyserial", file=sys.stderr)
        return 3

    output = bytearray()
    try:
        with serial.Serial(
            port=a.port, baudrate=115200,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=0.15,
        ) as ser:
            ser.reset_input_buffer()
            print(f"LAB062_UART_OPEN: {a.port} 115200 8N1", flush=True)
            print("PRESS S1 RESET ON TANG NANO 9K NOW.", flush=True)
            until = time.monotonic() + a.seconds
            while time.monotonic() < until and len(output) < 4096:
                chunk = ser.read(128)
                if not chunk:
                    continue
                output.extend(chunk)
                print(f"LAB062_UART_CHUNK: {chunk!r}", flush=True)
                if BANNER in output:
                    break
    except serial.SerialException as exc:
        print(f"LAB062_UART_PORT_ERROR: {exc}", file=sys.stderr, flush=True)
        a.raw.parent.mkdir(parents=True, exist_ok=True)
        a.raw.write_bytes(output)
        return 2
    a.raw.parent.mkdir(parents=True, exist_ok=True)
    a.raw.write_bytes(output)
    print(f"LAB062_UART_BYTES_CAPTURED: {len(output)}", flush=True)
    if BANNER in output:
        print("LAB062_UART_BANNER_PASS: PICORV32 READY\\r\\n", flush=True)
        print("LAB062_LED_PHYSICAL_CHECK_PENDING", flush=True)
        return 0
    print("LAB062_UART_BANNER_NOT_CAPTURED; board UART PASS NOT ESTABLISHED", flush=True)
    return 1

if __name__ == "__main__":
    raise SystemExit(main())

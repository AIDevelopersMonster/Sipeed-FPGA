#!/usr/bin/env python3
"""HOST-01 UART SDHC sector reader: read-only, no filesystem edits."""
import argparse
import pathlib
import struct
import sys

POLY = 0x1021


def crc16(data):
    state = 0xffff
    for byte in data:
        state ^= byte << 8
        for _ in range(8):
            state = (((state << 1) ^ POLY) if state & 0x8000 else (state << 1)) & 0xffff
    return state


def request(lba):
    if not 0 <= lba <= 0xffffffff:
        raise ValueError("LBA must be unsigned 32-bit")
    h = b"\xa5\x01" + struct.pack("<I", lba)
    return h + struct.pack("<H", crc16(h))


def parse_response(raw, lba):
    if len(raw) < 9:
        raise ValueError(f"short response header/frame: {len(raw)} bytes")
    if raw[:2] != b"\x5a\x81":
        raise ValueError(f"bad magic/version: {raw[:2].hex()}")
    status = raw[2]
    got_lba = struct.unpack("<I", raw[3:7])[0]
    if got_lba != lba:
        raise ValueError(f"LBA mismatch: expected={lba}, actual={got_lba}")
    expected_length = 521 if status == 0 else 9
    if len(raw) != expected_length:
        raise ValueError(f"length mismatch: expected {expected_length}, got {len(raw)}")
    expected_crc = struct.unpack("<H", raw[-2:])[0]
    got_crc = crc16(raw[:-2])
    if got_crc != expected_crc:
        raise ValueError(f"CRC16 mismatch: calculated={got_crc:04X}, received={expected_crc:04X}")
    if status:
        raise ValueError(f"FPGA SDHC error E={status:02X}")
    return raw[7:-2]


def read_sector(port, lba, baud=115200, timeout=20.0):
    import serial
    with serial.Serial(port=port, baudrate=baud, timeout=timeout, write_timeout=timeout) as ser:
        ser.reset_input_buffer()
        ser.write(request(lba))
        ser.flush()
        h = ser.read(7)
        if len(h) != 7:
            raise ValueError(f"timeout/short response header: {h.hex()}")
        if h[:2] != b"\x5a\x81":
            raise ValueError(f"bad response header: {h.hex()}")
        status = h[2]
        tail = ser.read(514 if status == 0 else 2)
        return parse_response(h + tail, lba)


def main(argv=None):
    p = argparse.ArgumentParser(description="Read a 512-byte microSD sector via FPGA HOST-01 (read-only)")
    p.add_argument("--port", required=True, help="serial COM port e.g. COM10")
    p.add_argument("--lba", type=lambda x: int(x, 0), required=True, help="nonnegative 32-bit LBA")
    p.add_argument("--output", help="save exactly 512 raw bytes to the named file")
    p.add_argument("--compare-image", help="optional local full-card image to compare selected LBA")
    p.add_argument("--timeout", type=float, default=20.0)
    args = p.parse_args(argv)
    try:
        if not (0 <= args.lba <= 0xffffffff):
            raise ValueError("LBA out of range")
        if args.timeout <= 0:
            raise ValueError("timeout must be positive")
        data = read_sector(args.port, args.lba, timeout=args.timeout)
        if len(data) != 512:
            raise ValueError("wrong sector length")
        print(f"HOST01_READ_PASS LBA={args.lba} LENGTH={len(data)} CRC=PASS")
        print("HEX[0:64]:", data[:64].hex(" ", 1))
        if args.compare_image:
            with open(args.compare_image, "rb") as f:
                f.seek(args.lba * 512)
                expected = f.read(512)
            if data != expected:
                raise ValueError("HOST01_IMAGE_COMPARE_FAIL: card sector differs from local reference")
            print("HOST01_IMAGE_COMPARE_PASS")
        if args.output:
            pathlib.Path(args.output).write_bytes(data)
            print("HOST01_SAVED:", args.output)
        return 0
    except (OSError, ValueError, ImportError) as exc:
        print("HOST01_FAIL:", exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

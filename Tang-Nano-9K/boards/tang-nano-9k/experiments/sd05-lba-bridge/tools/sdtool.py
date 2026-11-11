#!/usr/bin/env python3
"""SD-05 read-only UART CLI. Requires tested SD-05 firmware, NOT SD-04."""
import argparse
import hashlib
import pathlib
import sys
import time
from protocol import request, parse_reply, ProtocolError

def read_exact(ser, n, timeout):
    out = bytearray()
    end = time.monotonic() + timeout
    while len(out) < n and time.monotonic() < end:
        out.extend(ser.read(n-len(out)))
    if len(out) != n:
        raise TimeoutError(f"partial reply {len(out)}/{n} bytes")
    return bytes(out)

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--port", required=True, help="UART COM port, e.g. COM10")
    ap.add_argument("--lba", type=lambda s:int(s,0), required=True)
    ap.add_argument("--out", type=pathlib.Path, required=True)
    ap.add_argument("--timeout", type=float, default=10.0)
    args = ap.parse_args()
    if args.timeout <= 0 or not 0 <= args.lba <= 0xFFFFFFFF:
        ap.error("invalid timeout/LBA")
    try:
        import serial
        with serial.Serial(args.port, baudrate=115200, timeout=0.1,
                           write_timeout=2, xonxoff=False, rtscts=False) as port:
            port.reset_input_buffer()
            seq=1
            pkt=request(args.lba,seq)
            port.write(pkt)
            port.flush()
            head=read_exact(port, 2, args.timeout)
            if head == b'ZE':
                raw=head+read_exact(port, 8, args.timeout)
            elif head == b'ZD':
                raw=head+read_exact(port, 521, args.timeout)
            else:
                raise ProtocolError(f"bad response prefix: {head.hex()}")
            data=parse_reply(raw,seq=seq,lba=args.lba).data
        args.out.write_bytes(data)
        print(f"SD05_READ_PASS: LBA={args.lba} BYTES={len(data)}")
        print(f"SD05_SECTOR_SHA256: {hashlib.sha256(data).hexdigest().upper()}")
        print(f"SD05_FILE: {args.out}")
        return 0
    except (OSError,TimeoutError,ProtocolError,ImportError) as e:
        print(f"SD05_READ_FAIL: {e}",file=sys.stderr)
        return 1

if __name__=="__main__":
    raise SystemExit(main())

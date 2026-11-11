#!/usr/bin/env python3
"""HOST-00 UART HELLO host CLI. No card I/O, no SD commands."""
import argparse
import sys

EXPECTED = b"HELLO\n"


def exchange(port, baud, timeout):
    import serial
    with serial.Serial(port=port, baudrate=baud, bytesize=8,
                       parity="N", stopbits=1, timeout=timeout,
                       write_timeout=timeout) as s:
        s.reset_input_buffer()
        s.write(b"H")
        s.flush()
        return s.read(len(EXPECTED))


def main(argv=None, transport=exchange):
    ap = argparse.ArgumentParser(description="HOST-00 UART HELLO probe")
    ap.add_argument("--port", required=True, help="COM10, etc.")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--timeout", type=float, default=3.0)
    ap.add_argument("--repeat", type=int, default=1)
    args = ap.parse_args(argv)
    if not 9600 <= args.baud <= 1000000 or not .1 <= args.timeout <= 30 or not 1 <= args.repeat <= 100:
        ap.error("baud / timeout / repeat out of range")
    for i in range(args.repeat):
        try:
            response = transport(args.port, args.baud, args.timeout)
        except (ImportError, OSError, ValueError) as exc:
            print("HOST00_ERROR: "+str(exc), file=sys.stderr)
            return 2
        if response != EXPECTED:
            print("HOST00_FAIL: attempt={} expected={!r} received={!r}".format(i+1,EXPECTED,response))
            return 1
        print("HOST00_HELLO_PASS: attempt={} port={} received={!r}".format(i+1,args.port,response))
    return 0


if __name__ == "__main__":
    sys.exit(main())

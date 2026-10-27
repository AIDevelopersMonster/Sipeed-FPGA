#!/usr/bin/env python3
"""W01: UART-only 23-byte frame capture. No writes to serial port or FPGA."""
import argparse
import json
import re
import sys
import time
from pathlib import Path

FRAME = re.compile(rb"W01:([0-9A-F]{8}):([0-9A-F]{8})\r\n")
EXPECTED_DIGEST = "B26F8CA7"

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--cpu", choices=("pico","neo"), required=True)
    p.add_argument("--port", default="COM10")
    p.add_argument("--seconds", type=int, default=30)
    p.add_argument("--raw", type=Path, required=True)
    p.add_argument("--json", type=Path, required=True)
    a = p.parse_args()
    if not 5 <= a.seconds <= 90:
        p.error("seconds must be 5..90")
    try:
        import serial
    except ImportError:
        print("W01_PYSERIAL_REQUIRED: python -m pip install pyserial", file=sys.stderr)
        return 3
    data = bytearray()
    match = None
    failure = None
    try:
        with serial.Serial(a.port, 115200, bytesize=serial.EIGHTBITS,
                           parity=serial.PARITY_NONE,
                           stopbits=serial.STOPBITS_ONE, timeout=0.15) as ser:
            ser.reset_input_buffer()
            print("W01_UART_OPEN: " + a.port + " 115200 8N1",flush=True)
            print("PRESS S1 RESET ON TANG NANO 9K NOW.",flush=True)
            deadline = time.monotonic() + a.seconds
            while time.monotonic() < deadline and len(data)<4096:
                chunk = ser.read(128)
                if chunk:
                    data.extend(chunk)
                    print("W01_UART_CHUNK: " + repr(chunk),flush=True)
                    match = FRAME.search(data)
                    if match:
                        break
    except serial.SerialException as e:
        failure = str(e)
    a.raw.parent.mkdir(parents=True,exist_ok=True)
    a.json.parent.mkdir(parents=True,exist_ok=True)
    a.raw.write_bytes(data)
    digest,cycles = None,None
    status = "FAIL"
    if match:
        digest = match.group(1).decode("ascii")
        cycles = int(match.group(2),16)
        if digest == EXPECTED_DIGEST and 100 <= cycles <= 1000000:
            status="UART_PASS_LED_PENDING"
        else:
            failure="Digest or cycle range mismatch"
    elif failure is None:
        failure="W01 frame not received"
    result = {"cpu":a.cpu,"port":a.port,"status":status,"digest":digest,
              "cycles":cycles,"raw_bytes":len(data),"error":failure,
              "leds":"OPERATOR_CONFIRMATION_PENDING"}
    a.json.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print("W01_UART_JSON: " + str(a.json),flush=True)
    if status=="UART_PASS_LED_PENDING":
        print("W01_"+a.cpu.upper()+"_UART_PASS: digest="+digest+" cycles="+str(cycles)+" bytes=23",flush=True)
        print("W01_LED_CONFIRMATION_PENDING: verify 3 lit LEDs",flush=True)
        return 0
    print("W01_"+a.cpu.upper()+"_UART_FAIL: "+str(failure),file=sys.stderr,flush=True)
    return 2

if __name__=="__main__":
    sys.exit(main())

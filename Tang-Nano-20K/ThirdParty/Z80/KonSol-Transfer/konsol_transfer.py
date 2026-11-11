#!/usr/bin/env python3
"""KonSol Transfer KX1 v0.1: loss-detecting ASCII serial transport for BBC BASIC.

Windows -> CP/Mish and CP/Mish -> Windows over one COM port at 115200 8N1.
This program NEVER accesses a physical disk or the FPGA programming interface.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import time
import zlib
from pathlib import Path

MAX_SIZE = 524288
CHUNK = 64
SERIAL_BAUD = 115200
NAME_RE = re.compile(r"^[AB]:[A-Z0-9_\-]{1,8}\.[A-Z0-9_\-]{1,3}$")
HEX_DIGITS = "0123456789ABCDEF"


class TransferError(RuntimeError):
    pass


def normalized_name(raw: str) -> str:
    name = raw.strip().upper()
    if not NAME_RE.fullmatch(name):
        raise TransferError(f"CP/M destination/source must be A:NAME.EXT or B:NAME.EXT (8.3): {raw!r}")
    if name.endswith(":KXFER.TMP"):
        raise TransferError("KXFER.TMP is the reserved transfer staging filename")
    return name


def adler_pair(data: bytes) -> tuple[int, int]:
    a = zlib.adler32(data) & 0xFFFFFFFF
    return a & 0xFFFF, a >> 16


def encode_frame(index: int, chunk: bytes) -> str:
    if len(chunk) > CHUNK or index < 0 or index > 999999:
        raise TransferError("Invalid transfer frame")
    return f"D{index:06d}:{chunk.hex().upper()}:{sum(chunk) & 255:02X}"


def decode_frame(frame: str, expected_index: int, byte_count: int) -> bytes:
    match = re.fullmatch(r"D([0-9]{6}):([A-F0-9]*):([A-F0-9]{2})", frame)
    if match is None or int(match.group(1)) != expected_index:
        raise TransferError(f"Unexpected transfer frame #{expected_index}: {frame[:50]}")
    try:
        raw = bytes.fromhex(match.group(2))
    except ValueError as e:
        raise TransferError("Invalid HEX in data frame") from e
    if len(raw) != byte_count or (sum(raw) & 255) != int(match.group(3), 16):
        raise TransferError(f"Invalid length or block checksum in frame #{expected_index}")
    return raw


def parse_done(message: str) -> tuple[int, int]:
    match = re.fullmatch(r"KX1:DONE:\s*(\d+)\s*:\s*(\d+)\s*", message)
    if not match:
        raise TransferError(f"Invalid completion status: {message}")
    return int(match.group(1)), int(match.group(2))


class Protocol:
    def __init__(self, port, *, pace_ms: float = 1, timeout: float = 20, verbose: bool = False):
        self.port = port
        self.pace_ms = pace_ms
        self.timeout = timeout
        self.verbose = verbose
        self._line = bytearray()

    def putline(self, line: str):
        content = line.encode("ascii") + b"\r"
        if self.verbose and not line.startswith("D"):
            print(f"TX: {line}")
        if self.pace_ms > 0:
            for b in content:
                self.port.write(bytes((b,)))
                time.sleep(self.pace_ms / 1000)
        else:
            self.port.write(content)
        self.port.flush()

    def _rawline(self, deadline: float) -> str:
        while time.monotonic() < deadline:
            b = self.port.read(1)
            if not b:
                continue
            if b in (b"\r", b"\n"):
                if not self._line:
                    continue
                result = self._line.decode("latin1", errors="replace")
                self._line.clear()
                return result
            self._line.extend(b)
            if len(self._line) > 2048:
                self._line.clear()
                raise TransferError("Serial line too long; protocol out of sync")
        raise TransferError("Timeout waiting for FPGA response (COM25 busy, receiver not RUN, or transmission stalled)")

    def status(self, *, timeout: float | None = None) -> str:
        deadline = time.monotonic() + (self.timeout if timeout is None else timeout)
        while time.monotonic() < deadline:
            line = self._rawline(deadline)
            index = line.rfind("KX1:")
            if index < 0:
                if self.verbose and line.strip():
                    print(f"RX echo: {line[:100]}")
                continue
            message = line[index:].strip()
            if self.verbose:
                print("RX:", message[:110])
            return message
        raise TransferError("No protocol response")

    def expect(self, prefix: str, *, timeout: float | None = None) -> str:
        deadline = time.monotonic() + (self.timeout if timeout is None else timeout)
        while time.monotonic() < deadline:
            msg = self.status(timeout=max(.01, deadline-time.monotonic()))
            if msg.startswith("KX1:ERR:"):
                raise TransferError(f"FPGA receiver: {msg}")
            if msg.startswith(prefix):
                return msg
            if msg == "KX1:READY":
                continue
            # Caller treats stale statuses as protocol errors rather than suppressing them.
            raise TransferError(f"Expected {prefix!r}, received {msg!r}")
        raise TransferError(f"Timeout waiting for {prefix}")

    def send_bytes(self, name: str, payload: bytes, *, retries: int = 4, verify_timeout: float = 240) -> None:
        name = normalized_name(name)
        if len(payload) > MAX_SIZE:
            raise TransferError(f"KX1 v0.1 limits files to {MAX_SIZE} bytes")
        full_checksum = adler_pair(payload)
        self.putline("P")
        self.expect("KX1:NAME")
        self.putline(name)
        self.expect("KX1:SIZE")
        self.putline(str(len(payload)))
        self.expect("KX1:SUM1")
        self.putline(str(full_checksum[0]))
        self.expect("KX1:SUM2")
        self.putline(str(full_checksum[1]))
        self.expect("KX1:GO")
        last_completed = None
        frames = (len(payload)+CHUNK-1)//CHUNK
        for index in range(frames):
            part = payload[index*CHUNK:(index+1)*CHUNK]
            frame = encode_frame(index, part)
            accepted = False
            for attempt in range(retries):
                self.putline(frame)
                try:
                    msg = self.status()
                except TransferError as e:
                    if "Timeout" in str(e) and attempt+1 < retries:
                        continue
                    raise
                if msg.startswith("KX1:ERR:"):
                    raise TransferError(f"FPGA transfer aborted: {msg}")
                if msg.startswith("KX1:ACK:"):
                    seq = int(msg.split(":")[-1].strip())
                    if seq == index:
                        accepted = True
                        break
                    if seq == index-1:
                        continue
                    raise TransferError(f"Unexpected ACK #{seq} for block #{index}")
                if msg.startswith("KX1:NAK:"):
                    continue
                if index == frames-1 and msg.startswith("KX1:DONE:"):
                    # The final ACK can be lost; DONE with verified checksum is sufficient.
                    last_completed = msg
                    accepted = True
                    break
                raise TransferError(f"Unexpected FPGA response to block {index}: {msg}")
            if not accepted:
                raise TransferError(f"Frame #{index} failed after {retries} tries; check SD for KXFER.TMP")
            if frames > 8 and (index+1)%max(1,frames//8)==0:
                print(f"  Send {index+1}/{frames} blocks ({100*(index+1)//frames}%)")
        done = last_completed or self.expect("KX1:DONE:", timeout=verify_timeout)
        reported = parse_done(done)
        if reported != full_checksum:
            raise TransferError(f"END-TO-END CHECKSUM MISMATCH: host={full_checksum} FPGA={reported}")

    def get_bytes(self, name: str, *, exact_length: int | None = None, retries: int = 4) -> tuple[bytes, int]:
        name = normalized_name(name)
        self.putline("G")
        self.expect("KX1:NAME")
        self.putline(name)
        ext = self.expect("KX1:EXT:")
        match = re.fullmatch(r"KX1:EXT:\s*(\d+)\s*", ext)
        if match is None:
            raise TransferError(f"Invalid CP/M file extent: {ext}")
        allocated = int(match.group(1))
        length = allocated if exact_length is None else exact_length
        if length < 0 or length > allocated or length > MAX_SIZE:
            raise TransferError(f"Requested exact length {length} exceeds CP/M extent {allocated} or v0.1 limit")
        self.putline(str(length))
        self.expect("KX1:GO")
        received = bytearray()
        frames = (length+CHUNK-1)//CHUNK
        for index in range(frames):
            size = min(CHUNK, length - len(received))
            matched = False
            for attempt in range(retries):
                msg = self.status()
                if msg.startswith("KX1:ERR:"):
                    raise TransferError(f"FPGA transfer aborted: {msg}")
                if not msg.startswith("KX1:D"):
                    raise TransferError(f"Expected KX1:D frame #{index}, received {msg}")
                previous = re.match(r"KX1:D([0-9]{6}):", msg)
                if previous and int(previous.group(1)) == index-1:
                    # ACK for the preceding block was lost; do not append it twice.
                    self.putline(f"A{index-1:06d}")
                    continue
                try:
                    block = decode_frame(msg[4:], index, size)
                except TransferError:
                    self.putline(f"N{index:06d}")
                    continue
                received.extend(block)
                self.putline(f"A{index:06d}")
                matched = True
                break
            if not matched:
                raise TransferError(f"FPGA-to-Windows frame #{index} invalid after {retries} attempts")
            if frames > 8 and (index+1)%max(1,frames//8)==0:
                print(f"  Receive {index+1}/{frames} blocks ({100*(index+1)//frames}%)")
        final = self.expect("KX1:DONE:", timeout=90)
        if parse_done(final) != adler_pair(received):
            raise TransferError("Download checksum mismatch; output file NOT created")
        return bytes(received), allocated


def _open_serial(name: str):
    try:
        import serial
    except ImportError as e:
        raise TransferError("Requires pyserial. Install once: python -m pip install pyserial") from e
    try:
        return serial.Serial(port=name, baudrate=SERIAL_BAUD, bytesize=serial.EIGHTBITS,
                             parity=serial.PARITY_NONE, stopbits=serial.STOPBITS_ONE,
                             timeout=0.12, write_timeout=10, xonxoff=False,
                             rtscts=False, dsrdtr=False)
    except serial.SerialException as e:
        raise TransferError(f"Cannot open {name}. Close MobaXterm first. {e}") from e


def _state_path(custom: str | None):
    return Path(custom) if custom else Path(__file__).resolve().with_name("KXFER_STATE.json")


def _read_state(path: Path) -> dict:
    if not path.is_file():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise TransferError("Invalid local transfer manifest")
    return data


def _save_state(path: Path, value: dict) -> None:
    temp = path.with_name(path.name + ".tmp")
    temp.write_text(json.dumps(value, sort_keys=True, indent=2)+"\n", encoding="utf-8")
    temp.replace(path)


def _validate_source(src: Path) -> bytes:
    if not src.is_file():
        raise TransferError(f"Missing Windows source: {src}")
    size = src.stat().st_size
    if size > MAX_SIZE:
        raise TransferError(f"File {size} bytes exceeds v0.1 maximum {MAX_SIZE}")
    return src.read_bytes()


def run_transfer(args, port=None):
    if args.command == "install":
        return run_install(args, port)
    state_path = _state_path(args.state)
    state = _read_state(state_path)
    remote = normalized_name(args.remote)
    if args.command == "send":
        local = Path(args.local)
        payload = _validate_source(local)
        print(f"SEND {local} -> {remote} ({len(payload)} bytes)")
        if port is None:
            with _open_serial(args.port) as port:
                Protocol(port, pace_ms=args.pace_ms, verbose=args.verbose).send_bytes(remote, payload)
        else:
            Protocol(port, pace_ms=args.pace_ms, verbose=args.verbose).send_bytes(remote, payload)
        state[remote] = {"size":len(payload),"sha256":hashlib.sha256(payload).hexdigest(),
                         "adler32":f"{zlib.adler32(payload)&0xffffffff:08X}"}
        _save_state(state_path, state)
        print("KX1 SEND + SD READBACK VERIFY: HOST-TO-BOARD PASS")
        print(f"SHA256 {state[remote]['sha256']}")
        return
    if args.command == "get":
        dst = Path(args.local)
        if dst.exists() and not args.overwrite:
            raise TransferError(f"Windows output already exists (no overwrite): {dst}")
        meta = state.get(remote)
        exact = args.length
        if args.full:
            exact = None
        elif exact is None and meta is not None:
            exact = int(meta["size"])
        description = "CP/M allocated length" if exact is None else f"exact {exact} bytes"
        print(f"GET {remote} -> {dst} ({description})")
        if port is None:
            with _open_serial(args.port) as port:
                payload, allocated = Protocol(port, pace_ms=args.pace_ms, verbose=args.verbose).get_bytes(remote,exact_length=exact)
        else:
            payload, allocated = Protocol(port, pace_ms=args.pace_ms, verbose=args.verbose).get_bytes(remote,exact_length=exact)
        sha256 = hashlib.sha256(payload).hexdigest()
        if meta is not None and not args.full and args.length is None and sha256 != meta["sha256"]:
            raise TransferError("Local manifest checksum differs from remote file; output NOT written. Use get --full for a changed file")
        tmp = dst.with_name(dst.name + ".kxpart")
        if tmp.exists():
            raise TransferError(f"Temporary output already exists: {tmp}")
        try:
            tmp.write_bytes(payload)
            if dst.exists() and not args.overwrite:
                raise TransferError(f"Output appeared during transfer: {dst}")
            tmp.replace(dst)
        except BaseException:
            tmp.unlink(missing_ok=True)
            raise
        print(f"KX1 GET + CHECKSUM VERIFY: HOST-TO-BOARD PASS; {len(payload)} bytes")
        if exact is None:
            print(f"NOTE: CP/M allocated {allocated} bytes; padding included. Use --length N when exact length is known.")
        print(f"SHA256 {sha256}")
        return
    raise TransferError(f"Unknown command: {args.command}")


def _prompt(port, max_seconds=12) -> tuple[str, str]:
    deadline = time.monotonic() + max_seconds
    data = bytearray()
    while time.monotonic() < deadline:
        byte = port.read(1)
        if not byte:
            continue
        data.extend(byte)
        if len(data) > 6000:
            data = data[-3000:]
        raw = data.decode("latin1", errors="replace")
        if raw.endswith("A>") or raw.endswith("B>"):
            return "CPM", raw
        if raw.endswith("\n>") or raw.endswith("\r>"):
            return "BASIC", raw
    raise TransferError(f"No A>/B>/BASIC > prompt. Last output: {bytes(data[-120:])!r}")


def run_install(args, port=None):
    source = Path(__file__).resolve().with_name("KXFER.BAS")
    numbered = source.read_text(encoding="ascii").splitlines()
    for line in numbered:
        if len(line) > 240:
            raise TransferError("BASIC install line exceeds safe terminal length")
    print("INSTALL KXFER.BBC (will clear BASIC RAM and save B:KXFER.BBC).")
    if not args.yes:
        reply = input("Type INSTALL to proceed: ").strip()
        if reply != "INSTALL":
            raise TransferError("Installation cancelled")
    owner = port is None
    if owner:
        port = _open_serial(args.port)
    try:
        protocol = Protocol(port, pace_ms=args.pace_ms, verbose=args.verbose)
        protocol.putline("")
        state, output = _prompt(port)
        if state != "CPM":
            raise TransferError("Install requires CP/Mish prompt A> or B>. Exit BASIC with *BYE first.")
        protocol.putline("BBCBASIC" if state=="CPM" else "")
        state, output = _prompt(port, 25)
        if state != "BASIC":
            raise TransferError("BBC BASIC console did not show > prompt")
        protocol.putline("NEW")
        _prompt(port)
        for i, line in enumerate(numbered):
            protocol.putline(line)
            _, output = _prompt(port, 15)
            if re.search(r"(?:Bad|Mistake|Syntax error|No room|Too big)\b",output,re.IGNORECASE):
                raise TransferError(f"BASIC refused line {line[:30]}: {output[-100:]}")
            if (i+1)%10 == 0 or i+1 == len(numbered):
                print(f"  BASIC {i+1}/{len(numbered)} lines")
        protocol.putline('SAVE "B:KXFER"')
        _, output = _prompt(port, 90)
        if re.search(r"(?:Error|No room|Directory full|Disk full|Bad name)\b",output,re.IGNORECASE):
            raise TransferError(f"BASIC SAVE failed: {output[-200:]}")
        protocol.putline("RUN")
        protocol.expect("KX1:READY",timeout=30)
        print("KX1 INSTALL / BASIC RUN: PROTOCOL READY (not FPGA hardware-verified until you test)")
        print("You may now use send/get; COM port released by this script.")
    finally:
        if owner:
            port.close()


def make_parser():
    p = argparse.ArgumentParser(description="KonSol Transfer KX1 v0.1 - serial file transfer to CP/Mish Z80")
    p.add_argument("--port",default="COM25",help="FPGA USB UART port, default COM25")
    p.add_argument("--pace-ms",type=float,default=1.0,help="inter-character send pacing to avoid FPGA UART overrun (default 1.0)")
    p.add_argument("--state",help="optional Windows manifest JSON path (default next to this script)")
    p.add_argument("--verbose",action="store_true")
    sub = p.add_subparsers(dest="command",required=True)
    i = sub.add_parser("install",help="one-time install of BASIC receiver from CP/M prompt A>")
    i.add_argument("--yes",action="store_true",help="confirm clearing BASIC RAM and saving B:KXFER.BBC")
    s = sub.add_parser("send",help="send Windows file to CP/M A: or B:")
    s.add_argument("local",help="Windows source pathname")
    s.add_argument("remote",help="CP/M destination e.g. B:TEST.COM")
    g = sub.add_parser("get",help="get CP/M file to Windows")
    g.add_argument("remote",help="CP/M source e.g. B:TEST.COM")
    g.add_argument("local",help="Windows output pathname")
    g.add_argument("--full",action="store_true",help="retrieve full CP/M 128-byte padded extent (ignore Windows manifest)")
    g.add_argument("--length",type=int,help="known exact original size, overriding local manifest")
    g.add_argument("--overwrite",action="store_true",help="explicitly overwrite existing Windows output after successful verification")
    return p


def main(argv=None):
    parser = make_parser()
    args = parser.parse_args(argv)
    if args.pace_ms < 0 or args.pace_ms > 50:
        parser.error("--pace-ms must be between 0 and 50")
    try:
        run_transfer(args)
        return 0
    except TransferError as e:
        print("KX1 ERROR:", e, file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())

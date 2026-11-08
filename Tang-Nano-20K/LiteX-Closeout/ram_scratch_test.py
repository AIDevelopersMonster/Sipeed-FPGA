#!/usr/bin/env python3
"""Tang Nano 20K factory LiteX: bounded SDRAM scratch test with restoration.

Default behavior is inert. --self-test runs offline mock regressions.
--run uses 8 words at 0x40012000 and requires an active factory BIOS prompt.
No FPGA Flash, ROM, peripheral writes, boot, or IRQ configuration.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
import time
import unittest
from datetime import datetime
from pathlib import Path

START = 0x40012000
COUNT = 8
SOURCE = "Tang Nano 20K factory LiteX b05c3069"
SCRATCH = tuple(START + 4 * i for i in range(COUNT))
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
PROMPT = re.compile(r"litex>\s*$", re.IGNORECASE)
ERROR = re.compile(r"unknown command|incorrect argument|command not found", re.IGNORECASE)
REGION = re.compile(r"(?mi)^\s*MAIN_RAM\s+0x40000000\s+0x800000\s*$")


def clean(text: str) -> str:
    return ANSI.sub("", text)


def parse_word(reply: str, address: int) -> int:
    marker = re.search(r"Memory dump:", clean(reply), re.IGNORECASE)
    if marker is None:
        raise ValueError(f"No Memory dump header for 0x{address:08X}")
    tail = clean(reply)[marker.end():]
    match = re.search(
        rf"0x{address:08x}[ \t]{{2,}}((?:[0-9a-f]{{2}}[ \t]+){{4}})",
        tail,
        re.IGNORECASE,
    )
    if not match:
        raise ValueError(f"Cannot parse four bytes at 0x{address:08X}: {tail[-160:]!r}")
    raw = bytes(int(v, 16) for v in re.findall(r"[0-9a-f]{2}", match.group(1), re.I))
    if len(raw) != 4:
        raise ValueError(f"Unexpected byte count at 0x{address:08X}")
    return int.from_bytes(raw, "little")


def value_for(phase: str, address: int) -> int:
    return {
        "ZERO": 0x00000000,
        "ONES": 0xFFFFFFFF,
        "ALT_A": 0xAAAAAAAA,
        "ALT_5": 0x55555555,
        "ADDRESS": (address ^ 0xA5A5A5A5) & 0xFFFFFFFF,
    }[phase]


PHASES = ("ZERO", "ONES", "ALT_A", "ALT_5", "ADDRESS")


class SerialBios:
    def __init__(self, port_name: str, timeout: float = 7):
        try:
            import serial
        except ImportError as exc:
            raise RuntimeError("pyserial required; use installed LiteX virtualenv") from exc
        self.ser = serial.Serial(port_name, baudrate=115200, bytesize=8,
                                 parity="N", stopbits=1, timeout=0.1,
                                 write_timeout=2)
        self.timeout = timeout

    def command(self, command: str) -> str:
        self.ser.reset_input_buffer()
        self.ser.write((command + "\r").encode("ascii"))
        deadline = time.monotonic() + self.timeout
        parts = bytearray()
        while time.monotonic() < deadline:
            data = self.ser.read(self.ser.in_waiting or 1)
            if data:
                parts.extend(data)
                if len(parts) > 131072:
                    raise RuntimeError("Oversized UART response (131072 bytes)")
                plain = clean(parts.decode("latin-1", "replace"))
                if PROMPT.search(plain):
                    if ERROR.search(plain):
                        raise RuntimeError(f"LiteX BIOS rejected {command!r}: {plain[-250:]}")
                    return plain
            else:
                time.sleep(0.01)
        raise TimeoutError(f"BIOS prompt timeout after {command!r}; "
                           f"received {clean(parts.decode('latin-1', 'replace'))[-200:]!r}")

    def close(self) -> None:
        self.ser.close()


class MemoryBios:
    def __init__(self, port):
        self.port = port

    def handshake(self) -> None:
        answer = self.port.command("")
        if "litex>" not in clean(answer):
            raise RuntimeError("No LiteX prompt")

    def preflight(self) -> str:
        output = self.port.command("mem_list")
        if not REGION.search(output.replace("\r", "\n")):
            raise RuntimeError("Unexpected MAIN_RAM map; refusing all writes")
        return output

    def read_word(self, address: int) -> int:
        return parse_word(self.port.command(f"mem_read 0x{address:08X} 4"), address)

    def write_word(self, address: int, value: int) -> None:
        self.port.command(f"mem_write 0x{address:08X} 0x{value:08X}")


def write_durable(path: Path, content: str) -> None:
    with path.open("x", encoding="utf-8") as fp:
        fp.write(content)
        fp.flush()
        os.fsync(fp.fileno())


def run_test(bios: MemoryBios, evidence_dir: Path, port: str) -> dict:
    evidence_dir.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    result_file = evidence_dir / f"RAM_SCRATCH_{timestamp}.json"
    backup_file = evidence_dir / f"RAM_BACKUP_{timestamp}.json"
    report = {"date_local": datetime.now().isoformat(), "source": SOURCE,
              "port": port, "scratch_start": f"0x{START:08X}",
              "scratch_words": COUNT, "phases": list(PHASES),
              "hardware_pass": False, "restore_pass": False,
              "phase_results": [], "error": None}
    saved: dict[int, int] = {}
    will_restore = False
    problems = []
    try:
        bios.handshake()
        report["mem_list"] = bios.preflight()
        print("PASS BIOS prompt and expected SDRAM map")
        for addr in SCRATCH:
            saved[addr] = bios.read_word(addr)
        backup = {"source": SOURCE, "port": port,
                  "words": [{"address": f"0x{addr:08X}",
                             "original": f"0x{saved[addr]:08X}"} for addr in SCRATCH]}
        write_durable(backup_file, json.dumps(backup, indent=2) + "\n")
        print(f"BACKUP SAVED BEFORE WRITE: {backup_file}")
        will_restore = True  # Set before issuing first possible write.
        for phase in PHASES:
            # Write all words first; read all words afterwards to detect aliasing.
            for addr in SCRATCH:
                bios.write_word(addr, value_for(phase, addr))
            for addr in SCRATCH:
                actual = bios.read_word(addr)
                expected = value_for(phase, addr)
                if actual != expected:
                    raise AssertionError(
                        f"{phase}: 0x{addr:08X} expected 0x{expected:08X}, "
                        f"read 0x{actual:08X}")
            report["phase_results"].append({"phase": phase, "verified_words": COUNT})
            print(f"PASS RAM phase {phase}: {COUNT}/{COUNT} words")
        report["patterns_pass"] = True
    except BaseException as exc:
        report["error"] = f"{type(exc).__name__}: {exc}"
        problems.append(report["error"])
        print(f"RAM TEST ERROR: {report['error']}", file=sys.stderr)
    finally:
        if will_restore:
            # Even if a write/readback failed, restore original words and verify.
            for addr in SCRATCH:
                try:
                    bios.write_word(addr, saved[addr])
                except BaseException as exc:
                    problems.append(f"RESTORE WRITE 0x{addr:08X}: {exc}")
            for addr in SCRATCH:
                try:
                    got = bios.read_word(addr)
                    if got != saved[addr]:
                        problems.append(f"RESTORE READ 0x{addr:08X}: "
                                        f"0x{got:08X} != 0x{saved[addr]:08X}")
                except BaseException as exc:
                    problems.append(f"RESTORE READ 0x{addr:08X}: {exc}")
            report["restore_pass"] = not any(x.startswith("RESTORE") for x in problems)
            print("RESTORE " + ("PASS: originals match 8/8" if report["restore_pass"]
                                 else "FAILED: inspect backup file"))
        report["errors"] = problems
        report["hardware_pass"] = bool(report.get("patterns_pass") and
                                        report["restore_pass"] and not problems)
        # Do not lose the report if a failure occurs. The pre-write backup remains.
        write_durable(result_file, json.dumps(report, indent=2) + "\n")
        print(f"EVIDENCE: {result_file}")
    if problems:
        raise RuntimeError("RAM test/restore not confirmed: " + "; ".join(problems))
    print(f"RAM SCRATCH BOARD PASS: {COUNT} words x {len(PHASES)} patterns, "
          "full readback and original contents restored; NO FLASH / BOOT / IRQ")
    return report


class FakePort:
    def __init__(self, broken_map=False, corrupt=False):
        self.mem = {address: (address ^ 0xDEADBEEF) & 0xFFFFFFFF for address in SCRATCH}
        self.baseline = dict(self.mem)
        self.writes = 0
        self.broken_map = broken_map
        self.corrupt = corrupt
        self.bad_once = False

    def command(self, command: str) -> str:
        head = command + "\r\n"
        end = "\x1b[92;1mlitex\x1b[0m> "
        if not command:
            return head + end
        if command == "mem_list":
            return (head + "Available memory regions:\r\n" +
                    ("MAIN_RAM  0x40000000 0x800000\r\n" if not self.broken_map
                     else "MAIN_RAM  0x80000000 0x800000\r\n") + end)
        words = command.split()
        address = int(words[1], 16)
        if words[0] == "mem_write":
            self.writes += 1
            self.mem[address] = int(words[2], 16)
            return head + end
        if words[0] == "mem_read":
            v = self.mem[address]
            if self.corrupt and self.writes > 0 and not self.bad_once:
                v ^= 1
                self.bad_once = True
            raw = v.to_bytes(4, "little")
            return head + "Memory dump:\r\n" + f"0x{address:08x}  " + " ".join(
                f"{b:02x}" for b in raw) + "  ....\r\n" + end
        raise ValueError(f"Unknown mock command: {command}")


class Regression(unittest.TestCase):
    def test_parse_crlf_and_flat(self):
        p = FakePort()
        msg = p.command("mem_read 0x40012000 4")
        self.assertEqual(parse_word(msg, START), p.mem[START])
        self.assertEqual(parse_word(msg.replace("\r\n", " "), START), p.mem[START])

    def test_parse_reject_wrong_address(self):
        msg = FakePort().command("mem_read 0x40012000 4")
        with self.assertRaises(ValueError):
            parse_word(msg, START + 4)

    def test_normal_restores_every_word(self):
        port = FakePort()
        with tempfile.TemporaryDirectory() as td:
            result = run_test(MemoryBios(port), Path(td), "MOCK")
            self.assertTrue(result["hardware_pass"])
            self.assertEqual(port.mem, port.baseline)
            self.assertTrue(any(Path(td).glob("RAM_BACKUP_*.json")))

    def test_detects_corruption_and_restores(self):
        port = FakePort(corrupt=True)
        with tempfile.TemporaryDirectory() as td:
            with self.assertRaises(RuntimeError):
                run_test(MemoryBios(port), Path(td), "MOCK")
            self.assertGreater(port.writes, 0)
            self.assertEqual(port.mem, port.baseline)
            self.assertTrue(any(Path(td).glob("RAM_SCRATCH_*.json")))

    def test_wrong_memory_map_prevents_writes(self):
        port = FakePort(broken_map=True)
        with tempfile.TemporaryDirectory() as td:
            with self.assertRaises(RuntimeError):
                run_test(MemoryBios(port), Path(td), "MOCK")
            self.assertEqual(port.writes, 0)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--self-test", action="store_true", help="offline mock tests")
    mode.add_argument("--run", action="store_true", help="explicit 8-word SDRAM write/read/restore")
    parser.add_argument("--port", default="COM25", help="BIOS UART serial device")
    args = parser.parse_args()
    if args.self_test:
        result = unittest.TextTestRunner(verbosity=2).run(
            unittest.defaultTestLoader.loadTestsFromTestCase(Regression))
        return 0 if result.wasSuccessful() else 1
    print(f"SCRATCH: 0x{START:08X}..0x{SCRATCH[-1] + 3:08X}, "
          "8 words, 5 phases, saving originals before writes")
    print("Factory LiteX BIOS required; close other COM users. No Flash writes.")
    port = SerialBios(args.port)
    try:
        run_test(MemoryBios(port), Path(__file__).parent / "evidence", args.port)
        return 0
    finally:
        port.close()


if __name__ == "__main__":
    sys.exit(main())

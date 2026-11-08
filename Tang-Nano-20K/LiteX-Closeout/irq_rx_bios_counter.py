#!/usr/bin/env python3
"""Tang Nano 20K factory BIOS: bounded read-only UART RX ISR counter test.

Commands: empty CR, mem_list, mem_read 0x10000178 4, help.
No mem_write, IRQ-mask change, boot, or Flash operations.
Counter mapping comes from the specific verified 32-KiB factory ROM.
"""
from __future__ import annotations
import argparse
import json
import re
import sys
import tempfile
import unittest
from datetime import datetime
from pathlib import Path
from ram_scratch_test import SerialBios, parse_word

RX_PRODUCE = 0x10000178
READ = f"mem_read 0x{RX_PRODUCE:08X} 4"
EXPECTED = (len(READ) + 1, len("help") + 1 + len(READ) + 1)


def probe(bios):
    """Return values and expected differences; never modify target memory."""
    if "litex>" not in bios.command(""):
        raise RuntimeError("LiteX BIOS prompt absent")
    memlist = re.sub(r"\r", "\n", bios.command("mem_list"))
    if not re.search(r"(?mi)^\s*SRAM\s+0x10000000\s+0x2000\s*$", memlist):
        raise RuntimeError("Unexpected SRAM region; no counter reads")
    values = []
    for command in (READ, READ, "help", READ):
        reply = bios.command(command)
        if command == READ:
            n = parse_word(reply, RX_PRODUCE)
            if not 0 <= n <= 127:
                raise RuntimeError(f"RX counter invalid ({n})")
            values.append(n)
    got = ((values[1] - values[0]) & 127, (values[2] - values[1]) & 127)
    return values, got


def run(bios, evidence, port):
    result = {"status": "INCONCLUSIVE", "port": port,
              "time_local": datetime.now().isoformat(),
              "counter_address": f"0x{RX_PRODUCE:08X}",
              "expected_deltas": list(EXPECTED)}
    evidence.mkdir(exist_ok=True, parents=True)
    output = evidence / f"IRQ_RX_COUNTER_{datetime.now():%Y%m%d_%H%M%S_%f}.json"
    try:
        values, got = probe(bios)
        result.update(samples=values, deltas=got)
        if tuple(got) != EXPECTED:
            raise AssertionError("RX counter deltas differ; result INCONCLUSIVE, not IRQ FAIL")
        result["status"] = "BOARD_RX_ISR_CORRELATION_PASS"
        print(f"PASS BIOS UART RX ISR counter: {got[0]}/{EXPECTED[0]} and {got[1]}/{EXPECTED[1]} bytes")
    except Exception as exc:
        result["error"] = f"{type(exc).__name__}: {exc}"
        print("INCONCLUSIVE:", result["error"], file=sys.stderr)
    finally:
        with output.open("x", encoding="utf-8") as fh:
            json.dump(result, fh, indent=2)
            fh.write("\n")
        print("Evidence saved:", output)
    return result


class FakeBios:
    def __init__(self, enabled=True, correct_map=True):
        self.count, self.enabled, self.correct_map = 123, enabled, correct_map
        self.commands = []

    def command(self, cmd):
        self.commands.append(cmd)
        if self.enabled:
            self.count = (self.count + len(cmd) + 1) & 127
        prompt = "litex> "
        if cmd == "":
            return prompt
        if cmd == "mem_list":
            return ("SRAM 0x10000000 0x2000\r\n" if self.correct_map else
                    "SRAM 0x20000000 0x1000\r\n") + prompt
        if cmd == "help":
            return "BIOS help\r\n" + prompt
        if cmd == READ:
            byte_values = self.count.to_bytes(4, "little")
            return ("Memory dump:\r\n" + f"0x{RX_PRODUCE:08x}  " +
                    " ".join(f"{b:02x}" for b in byte_values) +
                    "       ....\r\n" + prompt)
        raise ValueError("Unknown mock command")


class Tests(unittest.TestCase):
    def test_success_with_wrap(self):
        with tempfile.TemporaryDirectory() as folder:
            mock = FakeBios()
            result = run(mock, Path(folder), "MOCK")
            self.assertEqual(result["status"], "BOARD_RX_ISR_CORRELATION_PASS")
            self.assertEqual(result["deltas"], EXPECTED)
            self.assertTrue(list(Path(folder).glob("IRQ_RX_COUNTER_*.json")))
            self.assertEqual(mock.commands, ["", "mem_list", READ, READ, "help", READ])

    def test_inactive_is_inconclusive(self):
        with tempfile.TemporaryDirectory() as folder:
            result = run(FakeBios(enabled=False), Path(folder), "MOCK")
            self.assertEqual(result["status"], "INCONCLUSIVE")

    def test_wrong_map_prevents_reads(self):
        with tempfile.TemporaryDirectory() as folder:
            mock = FakeBios(correct_map=False)
            result = run(mock, Path(folder), "MOCK")
            self.assertEqual(result["status"], "INCONCLUSIVE")
            self.assertNotIn(READ, mock.commands)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    mode = p.add_mutually_exclusive_group(required=True)
    mode.add_argument("--self-test", action="store_true")
    mode.add_argument("--run", action="store_true")
    p.add_argument("--port", default="COM25")
    opts = p.parse_args()
    if opts.self_test:
        result = unittest.TextTestRunner(verbosity=2).run(
            unittest.defaultTestLoader.loadTestsFromTestCase(Tests))
        return 0 if result.wasSuccessful() else 1
    print("Factory ROM ISR SRAM counter 0x10000178; commands are read-only")
    transport = SerialBios(opts.port)
    try:
        result = run(transport, Path(__file__).parent / "evidence", opts.port)
    finally:
        transport.close()
    return 0 if result["status"] == "BOARD_RX_ISR_CORRELATION_PASS" else 2


if __name__ == "__main__":
    sys.exit(main())

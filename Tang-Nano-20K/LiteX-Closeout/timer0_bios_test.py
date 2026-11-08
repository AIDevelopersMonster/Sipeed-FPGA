#!/usr/bin/env python3
"""Tang Nano 20K factory LiteX: bounded Timer0 test with state restoration.

--self-test : offline mock regressions only (no serial hardware).
--probe     : read-only factory ROM/CSR identity and timer configuration.
--run       : explicitly perform one 3-second one-shot on confirmed Timer0.
Never boots code, programs Flash, enables IRQs, or touches SDRAM.
"""
from __future__ import annotations

import argparse
import contextlib
import io
import json
import os
import re
import sys
import tempfile
import time
import unittest
from datetime import datetime
from pathlib import Path

from ram_scratch_test import SerialBios, parse_word

BASE = 0xF0002800
LOAD = BASE + 0x00
RELOAD = BASE + 0x04
ENABLE = BASE + 0x08
UPDATE = BASE + 0x0C
VALUE = BASE + 0x10
EVENT_STATUS = BASE + 0x14
EVENT_PENDING = BASE + 0x18
EVENT_ENABLE = BASE + 0x1C

FREQ = 48_000_000
TICKS = 3 * FREQ
# Real factory ROM, 32-KiB unique segment SHA-256:
# 3347be74e9716744949e572229345c3ea9e74f1740001408b934c0d85c79c5bc
ROM_SIGNATURE = {
    0x00003C84: 0xF0003437,   # lui s0, 0xf0003
    0x00003C88: 0x80042423,   # sw zero, -2040(s0): timer en
    0x00003C90: 0x80042223,   # sw zero, -2044(s0): timer reload
    0x00003CD4: 0xF00037B7,   # lui a5, 0xf0003
    0x00003D00: 0x8107A703,   # lw a4, -2032(a5): timer value
}
SAFE_WRITE_ADDRESSES = {LOAD, RELOAD, ENABLE, UPDATE, EVENT_PENDING}
ROM_REGION = re.compile(r"(?mi)^\s*ROM\s+0x00000000\s+0x20000\s*$")
CSR_REGION = re.compile(r"(?mi)^\s*CSR\s+0xf0000000\s+0x10000\s*$")


def read32(port, address):
    return parse_word(port.command(f"mem_read 0x{address:08X} 4"), address)


def write32(port, address, value):
    if address not in SAFE_WRITE_ADDRESSES:
        raise RuntimeError(f"Write allow-list violation 0x{address:08X}")
    if not 0 <= value <= 0xFFFFFFFF:
        raise ValueError("Invalid 32-bit value")
    port.command(f"mem_write 0x{address:08X} 0x{value:08X}")


def durable_json(path, data):
    with path.open("x", encoding="utf-8") as output:
        json.dump(data, output, indent=2, ensure_ascii=False)
        output.write("\n")
        output.flush()
        os.fsync(output.fileno())


def read_config(port):
    return {
        "load": read32(port, LOAD),
        "reload": read32(port, RELOAD),
        "en": read32(port, ENABLE),
        "ev_pending": read32(port, EVENT_PENDING),
        "ev_enable": read32(port, EVENT_ENABLE),
    }


def verify_identity(port):
    reply = port.command("")
    if "litex>" not in re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", reply).lower():
        raise RuntimeError("Factory BIOS prompt not found")
    memory = port.command("mem_list").replace("\r", "\n")
    if not ROM_REGION.search(memory) or not CSR_REGION.search(memory):
        raise RuntimeError("Unexpected factory ROM or CSR region. Refusing Timer access")
    matched = []
    for address, expected in ROM_SIGNATURE.items():
        actual = read32(port, address)
        if actual != expected:
            raise RuntimeError(
                f"Factory ROM mismatch at 0x{address:08X}: "
                f"0x{actual:08X} != 0x{expected:08X}; NO TIMER WRITES")
        matched.append(f"0x{address:08X}")
    return matched


def latched_timer_value(port):
    # Only UPDATE (no mask/IRQ changes) triggers a current counter snapshot.
    write32(port, UPDATE, 1)
    return read32(port, VALUE)


def restore_config(port, old):
    problems = []

    def attempt(name, fn):
        try:
            fn()
        except Exception as exc:
            problems.append(f"{name}: {exc}")

    # Stop our one-shot first. If original state was enabled and already
    # idle at value=0, re-enable with LOAD=0, then restore the saved LOAD
    # while EN=1: this avoids rearming the previous long timer.
    attempt("disable", lambda: write32(port, ENABLE, 0))
    if old["en"] == 1:
        attempt("load_zero", lambda: write32(port, LOAD, 0))
        attempt("reload_zero", lambda: write32(port, RELOAD, 0))
        attempt("reenable_idle", lambda: write32(port, ENABLE, 1))
        attempt("restore_load", lambda: write32(port, LOAD, old["load"]))
        attempt("restore_reload", lambda: write32(port, RELOAD, old["reload"]))
    else:
        attempt("restore_reload", lambda: write32(port, RELOAD, old["reload"]))
        attempt("restore_load", lambda: write32(port, LOAD, old["load"]))
        attempt("remain_disabled", lambda: write32(port, ENABLE, 0))

    # A completed one-shot may set Timer0 event pending (W1C), even with
    # IRQ delivery disabled. Clear only a newly-set bit, never an old event.
    try:
        pending_now = read32(port, EVENT_PENDING)
        if old["ev_pending"] == 0 and pending_now == 1:
            write32(port, EVENT_PENDING, 1)
    except Exception as exc:
        problems.append(f"event_pending_cleanup: {exc}")

    try:
        actual = read_config(port)
        for key in ("load", "reload", "en", "ev_enable", "ev_pending"):
            if actual[key] != old[key]:
                problems.append(
                    f"restore {key}: {actual[key]:08X} != {old[key]:08X}")
    except Exception as exc:
        problems.append(f"restored_config_readback: {exc}")
        actual = None
    return problems, actual


def run_test(port, evidence_dir, port_name, mode="run",
             monotonic=time.monotonic, sleeper=time.sleep, mock=False):
    evidence_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    report_file = evidence_dir / f"TIMER_TEST_{stamp}.json"
    backup_file = evidence_dir / f"TIMER_BACKUP_{stamp}.json"
    report = {
        "timestamp_local": datetime.now().isoformat(),
        "board": "Tang Nano 20K factory LiteX / VexRiscv_Min",
        "port": port_name,
        "mode": mode, "source": "LiteX b05c3069 + observed factory ROM",
        "target": f"0x{BASE:08X}",
        "oneshot_ticks": TICKS,
        "status": "INCONCLUSIVE",
        "restore_pass": False,
        "direct_irq_enable": False,
        "flash_writes": False,
    }
    old = None
    write_started = False
    restore_errors = []
    try:
        report["fingerprint_addresses"] = verify_identity(port)
        print(f"PASS factory ROM/CSR fingerprint {len(ROM_SIGNATURE)}/{len(ROM_SIGNATURE)}")
        old = read_config(port)
        report["original_config"] = old
        print("READ timer registers:", " ".join(f"{k}=0x{v:08X}" for k, v in old.items()))
        if mode == "probe":
            report["status"] = "READONLY_PROBE_PASS"
        else:
            # Prohibit interfering with a timer whose IRQ is enabled or which
            # may be partway through a countdown.
            if old["ev_enable"] != 0:
                raise RuntimeError("Timer event IRQ enabled; refusing to modify Timer0")
            if old["ev_pending"] not in (0, 1) or old["en"] not in (0, 1):
                raise RuntimeError("Unexpected Timer0 status/enable bits; refusing writes")
            # UPDATE has a latch side effect but no Timer control change.
            original_value = latched_timer_value(port)
            report["original_value"] = original_value
            if old["en"] == 1 and (original_value != 0 or old["reload"] != 0):
                raise RuntimeError("Timer0 active or periodic; refusing to interrupt it")
            durable_json(backup_file, {
                "board": report["board"], "time_local": report["timestamp_local"],
                "registers": old, "latched_value": original_value,
                "restore_rule": "idle-or-disabled Timer0, no IRQ enable",
            })
            print("BACKUP SAVED BEFORE CONTROL WRITES:", backup_file)
            report["backup_file"] = str(backup_file)
            write_started = True   # Any following command can change Timer0.
            write32(port, ENABLE, 0)
            write32(port, RELOAD, 0)
            write32(port, LOAD, TICKS)
            write32(port, ENABLE, 1)
            start = monotonic()

            first = latched_timer_value(port)
            print(f"TIMER initial read: {first} / {TICKS} ticks remaining")
            if not 0 < first <= TICKS:
                raise AssertionError("Timer did not start with nonzero countdown")
            sleeper(0.3)
            second = latched_timer_value(port)
            print(f"TIMER later read:   {second} ticks remaining")
            if not 0 < second < first:
                raise AssertionError("Timer did not demonstrably decrement")
            report["readings"] = {"first": first, "second": second}

            deadline = start + 7.0
            final = second
            while monotonic() < deadline:
                sleeper(0.25)
                final = latched_timer_value(port)
                if final == 0:
                    break
            report["readings"]["final"] = final
            report["elapsed_host_seconds"] = round(monotonic() - start, 3)
            if final != 0:
                raise AssertionError("Timer did not reach zero within bounded window")
            event_level = read32(port, EVENT_STATUS)
            report["event_status_at_zero"] = event_level
            if (event_level & 1) != 1:
                raise AssertionError("Timer zero event status was not asserted")
            print("PASS Timer0 one-shot: decrement, ZERO and event status bit")
            report["oneshot_pass"] = True
    except Exception as exc:
        report["error"] = f"{type(exc).__name__}: {exc}"
        print("TIMER INCONCLUSIVE:", report["error"], file=sys.stderr)
    finally:
        if write_started and old is not None:
            restore_errors, actual = restore_config(port, old)
            report["restore_readback"] = actual
            report["restore_errors"] = restore_errors
            report["restore_pass"] = not restore_errors
            print("RESTORE " + ("PASS: Timer control / event state" if not restore_errors
                                else "FAILED: do not rerun; inspect JSON and use RESET"))
        if report["status"] != "READONLY_PROBE_PASS":
            if report.get("oneshot_pass") and report["restore_pass"]:
                report["status"] = "MOCK_TIMER_PASS" if mock else "TIMER0_BOARD_PASS"
            elif restore_errors:
                report["status"] = "RESTORE_UNCONFIRMED"
        durable_json(report_file, report)
        print("Evidence saved:", report_file)

    if report["status"] == "TIMER0_BOARD_PASS":
        print("TIMER0 BOARD PASS: one-shot 3s, decremented, reached ZERO; "
              "restored config; NO FLASH / BOOT / IRQ ENABLE")
    if report["status"] == "READONLY_PROBE_PASS":
        print("READONLY PROBE PASS: NO TIMER WRITES / NO FLASH / NO BOOT")
    return report


class VirtualClock:
    def __init__(self):
        self.t = 0.

    def now(self):
        return self.t

    def sleep(self, seconds):
        self.t += seconds


class MockBios:
    def __init__(self, clock, bad_rom=False, irq_enabled=False,
                 running=False, bad_map=False, stuck=False, start_enabled=True):
        self.clock = clock
        self.bad_rom = bad_rom
        self.bad_map = bad_map
        self.stuck = stuck
        self.writes = []
        self.registers = {
            LOAD: 50_000, RELOAD: 0, ENABLE: int(start_enabled),
            EVENT_PENDING: 1 if start_enabled else 0,
            EVENT_ENABLE: int(irq_enabled),
        }
        self.running = bool(start_enabled)
        self.base_value = 50_000 if running else (0 if start_enabled else 50_000)
        self.started = self.clock.now()
        self.latched = self.base_value

    def value(self):
        if not self.running:
            return self.registers[LOAD]
        if self.stuck:
            return self.base_value
        remaining = max(0, self.base_value -
                        int((self.clock.now() - self.started) * FREQ))
        if remaining == 0:
            self.registers[EVENT_PENDING] = 1
        return remaining

    def command(self, command):
        self.clock.t += 0.008
        if command == "":
            return "litex> "
        if command == "mem_list":
            return ("ROM 0x00000000 0x20000\n" +
                    ("CSR 0xf0000000 0x10000\n" if not self.bad_map else
                     "CSR 0xe0000000 0x10000\n") + "litex> ")
        words = command.split()
        address = int(words[1], 16)
        if words[0] == "mem_read":
            if address in ROM_SIGNATURE:
                val = ROM_SIGNATURE[address] ^ (1 if self.bad_rom else 0)
            elif address == VALUE:
                val = self.latched
            elif address == EVENT_STATUS:
                val = int(self.value() == 0)
            else:
                val = self.registers[address]
            raw = val.to_bytes(4, "little")
            return ("Memory dump:\r\n" + f"0x{address:08x}  " +
                    " ".join(f"{z:02x}" for z in raw) + "  ....\r\nlitex> ")
        if words[0] == "mem_write":
            val = int(words[2], 16)
            if address not in SAFE_WRITE_ADDRESSES:
                raise AssertionError("unsafe mock write")
            self.writes.append((address, val))
            if address == UPDATE:
                self.latched = self.value()
            elif address == EVENT_PENDING:
                self.registers[EVENT_PENDING] &= ~val
            elif address == ENABLE:
                prior_value = self.value()
                self.registers[ENABLE] = val
                self.running = bool(val)
                self.base_value = (prior_value if val else self.registers[LOAD])
                self.started = self.clock.now()
            elif address == LOAD:
                self.registers[LOAD] = val
                if not self.running:
                    self.base_value = val
            else:
                self.registers[address] = val
            return "litex> "
        raise AssertionError(f"unknown mock BIOS command {command}")


class Regressions(unittest.TestCase):
    def perform(self, mock, mode="run"):
        with tempfile.TemporaryDirectory() as td:
            with contextlib.redirect_stdout(io.StringIO()), \
                 contextlib.redirect_stderr(io.StringIO()):
                result = run_test(mock, Path(td), "MOCK", mode=mode,
                                  monotonic=mock.clock.now,
                                  sleeper=mock.clock.sleep, mock=True)
            self.assertEqual(len(list(Path(td).glob("TIMER_TEST_*.json"))), 1)
            return result

    def test_enabled_idle_one_shot_and_restore(self):
        mock = MockBios(VirtualClock())
        before = dict(mock.registers)
        result = self.perform(mock)
        self.assertEqual(result["status"], "MOCK_TIMER_PASS")
        self.assertEqual(mock.registers, before)
        self.assertEqual(mock.value(), 0)

    def test_disabled_timer_restored(self):
        mock = MockBios(VirtualClock(), start_enabled=False)
        before = dict(mock.registers)
        result = self.perform(mock)
        self.assertEqual(result["status"], "MOCK_TIMER_PASS")
        self.assertEqual(mock.registers, before)

    def test_stuck_countdown_is_not_pass(self):
        mock = MockBios(VirtualClock(), stuck=True)
        result = self.perform(mock)
        self.assertNotIn("PASS", result["status"])
        self.assertTrue(result["restore_pass"])

    def test_running_timer_guards_control_writes(self):
        mock = MockBios(VirtualClock(), running=True)
        result = self.perform(mock)
        self.assertEqual(result["status"], "INCONCLUSIVE")
        self.assertFalse(any(a in (ENABLE, RELOAD, LOAD)
                             for a, _ in mock.writes))

    def test_enabled_irq_guards_all_writes(self):
        mock = MockBios(VirtualClock(), irq_enabled=True)
        result = self.perform(mock)
        self.assertEqual(result["status"], "INCONCLUSIVE")
        self.assertFalse(mock.writes)

    def test_wrong_rom_blocks_timer_access(self):
        mock = MockBios(VirtualClock(), bad_rom=True)
        result = self.perform(mock)
        self.assertEqual(result["status"], "INCONCLUSIVE")
        self.assertFalse(mock.writes)

    def test_bad_map_blocks_timer_access(self):
        mock = MockBios(VirtualClock(), bad_map=True)
        result = self.perform(mock)
        self.assertEqual(result["status"], "INCONCLUSIVE")
        self.assertFalse(mock.writes)

    def test_probe_no_writes(self):
        mock = MockBios(VirtualClock())
        result = self.perform(mock, mode="probe")
        self.assertEqual(result["status"], "READONLY_PROBE_PASS")
        self.assertEqual(mock.writes, [])


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    modes = ap.add_mutually_exclusive_group(required=True)
    modes.add_argument("--self-test", action="store_true")
    modes.add_argument("--probe", action="store_true")
    modes.add_argument("--run", action="store_true")
    ap.add_argument("--port", default="COM25")
    opts = ap.parse_args()
    if opts.self_test:
        suite = unittest.defaultTestLoader.loadTestsFromTestCase(Regressions)
        res = unittest.TextTestRunner(verbosity=2).run(suite)
        return 0 if res.wasSuccessful() else 1
    print("TIMER0: verified factory ROM, CSR 0xF0002800, 3-second one-shot")
    print("No Flash, SDRAM or IRQ_ENABLE writes. Close other COM users.")
    port = SerialBios(opts.port)
    try:
        report = run_test(port, Path(__file__).parent / "evidence", opts.port,
                          mode="run" if opts.run else "probe")
        return 0 if report["status"] in ("TIMER0_BOARD_PASS",
                                         "READONLY_PROBE_PASS") else 2
    finally:
        port.close()


if __name__ == "__main__":
    sys.exit(main())

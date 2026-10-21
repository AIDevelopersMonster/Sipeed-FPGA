"""Offline tests for the LAB-03.3 capture/metadata verifier; no FPGA needed."""

import importlib.util
import tempfile
import unittest
from pathlib import Path

SRC = Path(__file__).resolve().parents[1] / "tools" / "lab03_3_campaign.py"
spec = importlib.util.spec_from_file_location("lab03_3_campaign", SRC)
lab = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lab)


def sample(cmd=4, events=28, fetches=27, led="0x00000008", flags=None):
    if flags is None:
        flags = {"done": True, "truncated": False, "overlap": False,
                 "wrapped": False, "capturing": False}
    return (f"Opening COM10 at 115200 8N1\n"
            f"UART dump saved: C:\\tmp\\trace.txt\n"
            f"LAB03_2_TRACE_DECODE_PASS: command={cmd}, events={events}, "
            f"fetches={fetches}, LED_WRITE={led}, flags={flags}\n"
            "LAB03_2_BOARD_UART_DATA_PASS: transport and ROM-verified snapshot\n")


class CampaignTests(unittest.TestCase):
    def test_recorded_l4_runs_are_valid_even_with_different_fetch_counts(self):
        for events, fetches in ((26, 25), (28, 27)):
            parsed = lab.parse_probe_output(sample(events=events, fetches=fetches))
            self.assertEqual(lab.validate_parsed(parsed, 4), [])

    def test_off_is_valid(self):
        parsed = lab.parse_probe_output(sample(cmd=0, events=18, fetches=17,
                                               led="0x00000000"))
        self.assertEqual(lab.validate_parsed(parsed, 0), [])

    def test_wrong_led_is_failure(self):
        parsed = lab.parse_probe_output(sample(led="0x00000004"))
        self.assertTrue(any("LED_WRITE" in x for x in lab.validate_parsed(parsed, 4)))

    def test_missing_board_pass_is_failure(self):
        with self.assertRaises(ValueError):
            lab.parse_probe_output(sample().replace("LAB03_2_BOARD_UART_DATA_PASS", "MISSING"))

    def test_truncation_is_failure(self):
        flags = {"done": True, "truncated": True, "overlap": False,
                 "wrapped": False, "capturing": False}
        parsed = lab.parse_probe_output(sample(flags=flags))
        self.assertTrue(lab.validate_parsed(parsed, 4))

    def test_archive_tamper_detection(self):
        with tempfile.TemporaryDirectory() as root:
            folder = Path(root)
            (folder / "raw").mkdir()
            raw = folder / "raw" / "one.txt"
            raw.write_text("raw bytes", encoding="utf-8")
            row = {"index": 1, "requested_command": 4, "command": 4, "events": 28,
                   "fetches": 27, "led_write": "0x00000008", "status": "PASS",
                   "flags": {"done": True, "truncated": False, "overlap": False,
                             "wrapped": False, "capturing": False},
                   "raw_file": "raw/one.txt", "sha256": lab.sha256_file(raw)}
            self.assertEqual(lab.audit_rows(folder, [row]), [])
            raw.write_text("changed", encoding="utf-8")
            self.assertTrue(any("SHA256" in e for e in lab.audit_rows(folder, [row])))


if __name__ == "__main__":
    unittest.main()

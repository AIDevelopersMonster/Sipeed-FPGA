import unittest
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from sd04_decode import decode_frame, decode_entries

class DecoderTest(unittest.TestCase):
    def test_good_sector(self):
        s = bytearray(512)
        s[0:11] = b"HELLO   TXT"
        s[11] = 0x20
        s[26:28] = (5).to_bytes(2, "little")
        s[28:32] = (123).to_bytes(4, "little")
        s[32] = 0
        self.assertEqual(list(decode_entries(decode_frame(s.hex().upper().encode() + b"\r\n"))),
                         [(0, "HELLO.TXT", 0x20, 5, 123)])
    def test_fail_closed(self):
        with self.assertRaises(ValueError): decode_frame(b"ERROR\r\n")
        with self.assertRaises(ValueError): decode_frame(b"AB")
        with self.assertRaises(ValueError): decode_frame(b"0"*1023 + b"G")
        with self.assertRaises(ValueError): decode_frame(b"0"*1024 + b"\n0"*1024)
    def test_skips_lfn_and_deleted(self):
        s = bytearray(512)
        s[0] = 0xE5
        s[32] = 0x41
        s[32+11] = 0x0F
        s[64:75] = b"REPORT  BIN"
        s[64+11] = 0x20
        s[96] = 0
        self.assertEqual(list(decode_entries(s))[0][1], "REPORT.BIN")

if __name__ == "__main__":
    unittest.main()

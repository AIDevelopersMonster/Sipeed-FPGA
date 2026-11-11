import importlib.util
from pathlib import Path
import struct
import unittest

path = Path(__file__).resolve().parents[1] / "tools" / "host01_sector.py"
spec = importlib.util.spec_from_file_location("host01_sector", path)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class Protocol(unittest.TestCase):
    def test_vector(self):
        self.assertEqual(m.crc16(b"123456789"), 0x29b1)

    def test_request(self):
        req = m.request(0x12345678)
        self.assertEqual(req[:6], bytes.fromhex("A5 01 78 56 34 12"))
        self.assertEqual(m.crc16(req[:-2]), struct.unpack("<H", req[-2:])[0])

    def test_good_response(self):
        d = bytes(range(256)) * 2
        header = b"\x5a\x81\x00" + struct.pack("<I", 17472)
        body = header + d
        frame = body + struct.pack("<H", m.crc16(body))
        self.assertEqual(m.parse_response(frame, 17472), d)
        bad = bytearray(frame)
        bad[17] ^= 1
        with self.assertRaisesRegex(ValueError, "CRC16"):
            m.parse_response(bytes(bad), 17472)
        with self.assertRaisesRegex(ValueError, "LBA mismatch"):
            m.parse_response(frame, 0)

    def test_error_response(self):
        header = b"\x5a\x81\xe9" + struct.pack("<I", 2)
        frame = header + struct.pack("<H", m.crc16(header))
        with self.assertRaisesRegex(ValueError, "E=E9"):
            m.parse_response(frame, 2)

    def test_short_and_extra(self):
        with self.assertRaises(ValueError):
            m.parse_response(b"\x5a\x81", 0)
        data = bytes(512)
        header = b"\x5a\x81\x00" + struct.pack("<I", 0)
        raw = header + data + struct.pack("<H", m.crc16(header + data))
        with self.assertRaisesRegex(ValueError, "length"):
            m.parse_response(raw + b"x", 0)


if __name__ == "__main__":
    unittest.main()

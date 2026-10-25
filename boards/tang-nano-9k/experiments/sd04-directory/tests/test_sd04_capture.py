"""Offline protocol regression; no COM device or pyserial required."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from sd04_capture import validate_frame, receive_frame


class FakeSerial:
    def __init__(self, frame, chunk=31):
        self.buffer = bytearray(frame)
        self.chunk = chunk

    @property
    def in_waiting(self):
        return min(len(self.buffer), self.chunk)

    def read(self, n):
        n = min(n, len(self.buffer))
        out = self.buffer[:n]
        del self.buffer[:n]
        return bytes(out)


class FrameTests(unittest.TestCase):
    def setUp(self):
        self.sector = bytes((n * 41 + 7) % 256 for n in range(512))
        self.frame = self.sector.hex().upper().encode("ascii") + b"\r\n"

    def test_full_frame(self):
        self.assertEqual(validate_frame(self.frame), self.sector)
        self.assertEqual(receive_frame(FakeSerial(self.frame), 1), self.sector)

    def test_exact_31_byte_loss(self):
        truncated = self.sector[31:].hex().upper().encode() + b"\r\n"
        with self.assertRaisesRegex(ValueError, "962 HEX"):
            validate_frame(truncated)
        with self.assertRaisesRegex(ValueError, "962 HEX"):
            receive_frame(FakeSerial(truncated), 1)

    def test_error_frame(self):
        with self.assertRaisesRegex(ValueError, "FPGA reported"):
            validate_frame(b"ERROR\r\n")

    def test_reject_lowercase_and_wrong_delimiter(self):
        with self.assertRaisesRegex(ValueError, "non-uppercase"):
            validate_frame(self.sector.hex().encode() + b"\r\n")
        with self.assertRaisesRegex(ValueError, "CRLF"):
            validate_frame(self.frame[:-2] + b"\n")

    def test_reject_extra_bytes(self):
        with self.assertRaisesRegex(ValueError, "1024"):
            validate_frame(b"AA" + self.frame)
        with self.assertRaisesRegex(ValueError, "unexpected extra data"):
            receive_frame(FakeSerial(self.frame + b"X"), 1)


if __name__ == "__main__":
    unittest.main()

from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from fuzix_terminal import classify_tail, key_to_bytes


class TestTerminal(unittest.TestCase):
    def test_cpm_prompt(self):
        self.assertEqual(classify_tail(b'hello\r\nA>'), 'cpm_prompt')
        self.assertEqual(classify_tail(b'FUZIX not started\r\nB>'), 'cpm_prompt')

    def test_colored_prompt(self):
        self.assertEqual(classify_tail(b'\x1b[92mA>\x1b[0m'), 'cpm_prompt')

    def test_login(self):
        self.assertEqual(classify_tail(b'\r\nFUZIX 0.4\r\nlogin: '), 'fuzix_login')

    def test_receiver(self):
        self.assertEqual(classify_tail(b'KX1:READY\r\n'), 'kx_receiver')

    def test_controls(self):
        self.assertEqual(key_to_bytes('\r'), b'\r')
        self.assertEqual(key_to_bytes('\x08'), b'\x7f')
        self.assertEqual(key_to_bytes('\x08', backspace='bs'), b'\x08')
        self.assertIsNone(key_to_bytes('\x1d'))
        self.assertEqual(key_to_bytes('F'), b'F')


if __name__ == '__main__':
    unittest.main()
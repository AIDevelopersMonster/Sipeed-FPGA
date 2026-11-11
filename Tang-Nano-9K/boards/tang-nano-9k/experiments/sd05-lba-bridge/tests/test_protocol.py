import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from protocol import crc16, request, append_crc, parse_reply, synthetic_success, ProtocolError

class ProtocolTests(unittest.TestCase):
    def test_crc_vector(self):
        self.assertEqual(crc16(b'123456789'), 0x29B1)
    def test_request(self):
        packet = request(17472, 7)
        self.assertEqual(len(packet), 9)
        self.assertEqual(packet[:7], bytes([0xA5, 0x52, 7, 0x40, 0x44, 0, 0]))
        self.assertEqual(packet[-2:], crc16(packet[:-2]).to_bytes(2, 'little'))
    def test_data_and_rejections(self):
        src = bytes(range(256))*2
        frame = synthetic_success(17472, 7, src)
        self.assertEqual(len(frame), 523)
        self.assertEqual(parse_reply(frame, seq=7, lba=17472).data, src)
        for altered in [frame[:-1], b'X'+frame[1:], frame[:100]+b'!'+frame[101:]]:
            with self.assertRaises(ProtocolError): parse_reply(altered, seq=7, lba=17472)
        with self.assertRaises(ProtocolError): parse_reply(frame, seq=8, lba=17472)
        with self.assertRaises(ProtocolError): parse_reply(frame, seq=7, lba=64)
        bad_status = append_crc(frame[:7] + b'\x01\x00' + src)
        with self.assertRaises(ProtocolError): parse_reply(bad_status, seq=7, lba=17472)
        error = append_crc(bytes([0x5A, 0x45, 7, 0x40, 0x44, 0, 0, 2]))
        with self.assertRaisesRegex(ProtocolError, 'SD error'): parse_reply(error, seq=7, lba=17472)
    def test_range(self):
        with self.assertRaises(ProtocolError): request(-1, 0)
        with self.assertRaises(ProtocolError): request(0, 256)
if __name__ == '__main__':
    unittest.main()

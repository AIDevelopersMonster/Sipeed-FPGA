import sys
import struct
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from pikosol_xmodem import frame, crc16_ccitt, send_binary, TransferError


class FakeSerial:
    def __init__(self, blocks=3, fail_block=0, bad_length=False):
        self.rx = bytearray()
        self.stage = 'idle'
        self.blocks = blocks
        self.last = 0
        self.fail_block = fail_block
        self.bad_length = bad_length
        self.writes = []
    def write(self, data):
        self.writes.append(data)
        if data == b'LOAD\r':
            self.rx.extend(b'LOAD\r\nWaiting for downloader ...\r\nC')
            self.stage = 'data'
            return len(data)
        if len(data) == 133 and data[0] == 1:
            assert self.stage == 'data'
            n = data[1]
            assert data[2] ^ n == 255
            assert crc16_ccitt(data[3:131]) == int.from_bytes(data[131:133], 'big')
            if n == self.fail_block:
                self.rx.extend(b'\x15')
            else:
                assert n == self.last + 1
                self.last = n
                self.rx.extend(b'\x06')
            return len(data)
        if data == b'\x04':
            assert self.last == self.blocks
            self.rx.extend(b'\x06LOAD BAD LENGTH\r\nPiKoSoL> ' if self.bad_length else b'\x06LOAD OK\r\nPiKoSoL> ')
            self.stage = 'run'
            return 1
        if data == b'RUN\r':
            assert self.stage == 'run'
            self.rx.extend(b'run\r\nRUN 2000C010\r\nRUN RETURNED TO PiKoSoL\r\nPiKoSoL> ')
            return len(data)
        raise AssertionError(f'Unexpected TX: {data[:20]!r}')
    def read(self, n):
        if not self.rx:
            return b''
        b = bytes(self.rx[:n]);del self.rx[:n]
        return b
    def flush(self):
        pass


class ProtocolTest(unittest.TestCase):
    def test_crc_vector(self):
        self.assertEqual(crc16_ccitt(b'123456789'), 0x31c3)
        self.assertEqual(len(frame(1,b'ABC')), 133)
    def test_direct_transfer_and_run(self):
        image = struct.pack('<IIII', 0x31444b50, 304, 0x2000c010, 0)+bytes(288)
        device = FakeSerial(blocks=3)
        events = []
        res = send_binary(device,image,lambda *e: events.append(e),
                          handshake_timeout=.1, ack_timeout=.1, run_timeout=.2)
        self.assertTrue(res.returned)
        self.assertEqual(res.acked,res.blocks)
        self.assertEqual(res.blocks,3)
        self.assertEqual(sum(1 for t in events if t[0]=='ACK'),3)
    def test_reject_bad_length_never_sends_run(self):
        image = struct.pack('<IIII', 0x31444b50, 304, 0x2000c010, 0) + bytes(288)
        device = FakeSerial(blocks=3,bad_length=True)
        with self.assertRaisesRegex(TransferError, 'RUN NOT SENT'):
            send_binary(device,image,lambda *e: None,
                        handshake_timeout=.1, ack_timeout=.1,run_timeout=.2)
        self.assertNotIn(b'RUN\r', device.writes)

    def test_cancel_before_load_sends_no_bytes(self):
        image = struct.pack('<IIII', 0x31444b50, 304, 0x2000c010, 0)+bytes(288)
        device = FakeSerial(blocks=3)
        with self.assertRaisesRegex(TransferError, 'OPERATOR CANCEL'):
            send_binary(device, image, lambda *e: None,
                        cancel=lambda: True)
        self.assertEqual(device.writes, [])

    def test_cancel_after_load_before_first_xmodem_block(self):
        image = struct.pack('<IIII', 0x31444b50, 304, 0x2000c010, 0)+bytes(288)
        device = FakeSerial(blocks=3)
        stop = [False]
        def report(stage, done, total):
            if stage == 'LOAD sent':
                stop[0] = True
        with self.assertRaisesRegex(TransferError, 'OPERATOR CANCEL'):
            send_binary(device, image, report, cancel=lambda: stop[0],
                        handshake_timeout=.1, ack_timeout=.1)
        self.assertNotIn(b'RUN\r', device.writes)
        self.assertNotIn(b'\x04', device.writes)

    def test_cancel_after_load_success_never_runs(self):
        image = struct.pack('<IIII', 0x31444b50, 304, 0x2000c010, 0)+bytes(288)
        device = FakeSerial(blocks=3)
        def cancel():
            # EOT acknowledged and target LOAD OK in FakeSerial,
            # but a late operator cancel must block RUN.
            return device.stage == 'run'
        with self.assertRaisesRegex(TransferError, 'OPERATOR CANCEL'):
            send_binary(device, image, lambda *e: None, cancel=cancel,
                        handshake_timeout=.1, ack_timeout=.1)
        self.assertNotIn(b'RUN\r', device.writes)

    def test_retry_limit(self):
        image = struct.pack('<IIII', 0x31444b50, 204, 0x2000c010, 0)+bytes(188)
        device = FakeSerial(blocks=2,fail_block=1)
        with self.assertRaisesRegex(TransferError,'retries'):
            send_binary(device,image,lambda *e: None,
                        handshake_timeout=.1, ack_timeout=.1, retries=2)

if __name__ == '__main__':
    unittest.main()

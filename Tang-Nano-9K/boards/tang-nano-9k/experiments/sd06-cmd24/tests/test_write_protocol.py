import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from write_protocol import encode,decode,would_match_preimage,FrameError,FRAME_LEN
class WriteFrameTests(unittest.TestCase):
    def setUp(self):
        self.old=bytes(512)
        self.new=bytes(range(256))*2
        self.frame=encode(1,123456,self.old,self.new)
    def test_size_and_roundtrip(self):
        self.assertEqual(len(self.frame),FRAME_LEN)
        req=decode(self.frame)
        self.assertEqual((req.seq,req.lba),(1,123456))
        self.assertEqual(req.payload,self.new)
        self.assertTrue(would_match_preimage(req,self.old))
    def test_reject_corruption_and_truncation(self):
        for data in (self.frame[:-1], self.frame[:-1]+b"\x00",
                     bytes([0])+self.frame[1:]):
            with self.assertRaises(FrameError):decode(data)
    def test_changed_preimage(self):
        self.assertFalse(would_match_preimage(decode(self.frame),b"z"*512))
    def test_bounds(self):
        with self.assertRaises(FrameError):encode(1,0,self.old,self.new)
        with self.assertRaises(FrameError):encode(1,123,self.old,self.new[:-1])
        with self.assertRaises(FrameError):encode(256,123,self.old,self.new)
if __name__=="__main__":unittest.main()

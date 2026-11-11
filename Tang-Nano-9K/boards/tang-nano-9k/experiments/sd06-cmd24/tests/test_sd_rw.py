import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from sd_rw import crc16,packet,read_req,write_req,parse_reply,sha

class SdRWTests(unittest.TestCase):
 def setUp(self):
  self.old=bytes(512);self.new=bytes(range(256))*2;self.lba=10123;self.seq=7
 def test_read_wire_compatibility(self):
  req=read_req(self.lba,self.seq)
  self.assertEqual(len(req),9)
  self.assertEqual(req[:3],b"\xa5\x52\x07")
 def test_write_frame_1033(self):
  req=write_req(self.lba,self.seq,self.old,self.new)
  self.assertEqual(len(req),1033)
  self.assertEqual(req[:3],b"\xa5\x57\x07")
  self.assertEqual(req[7:519],self.old)
  self.assertEqual(req[519:1031],self.new)
  self.assertEqual(int.from_bytes(req[-2:],"little"),crc16(req[:-2]))
 def test_write_reply_success(self):
  b=packet(b"\x5a\x57"+bytes([self.seq])+self.lba.to_bytes(4,"little")+b"\x00")
  self.assertIsNone(parse_reply(b,self.seq,self.lba,0x57))
 def test_write_reply_error(self):
  b=packet(b"\x5a\x57"+bytes([self.seq])+self.lba.to_bytes(4,"little")+b"\xf9")
  with self.assertRaisesRegex(ValueError,"F9"):
   parse_reply(b,self.seq,self.lba,0x57)
 def test_reject_bad_crc_seq_lba(self):
  b=packet(b"\x5a\x57"+bytes([self.seq])+self.lba.to_bytes(4,"little")+b"\x00")
  for raw,seq,lba in ((b[:-1]+b"\x00",self.seq,self.lba),
    (b,self.seq+1,self.lba),(b,self.seq,self.lba+1)):
   with self.assertRaises(ValueError):parse_reply(raw,seq,lba,0x57)
 def test_read_reply(self):
  b=packet(b"\x5a\x44"+bytes([self.seq])+self.lba.to_bytes(4,"little")+b"\0\0"+self.new)
  self.assertEqual(parse_reply(b,self.seq,self.lba,0x44),self.new)
 def test_bad_size(self):
  with self.assertRaises(ValueError):write_req(self.lba,self.seq,self.old,self.new[:-1])
if __name__=="__main__":unittest.main()

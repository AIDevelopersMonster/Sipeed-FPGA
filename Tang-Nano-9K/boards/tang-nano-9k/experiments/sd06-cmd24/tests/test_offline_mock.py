import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from offline_mock import MockCard,WriteRejected,sha

class SafetyTests(unittest.TestCase):
    def setUp(self):
        self.card=MockCard("DISPOSABLE-SIM-01",500,bytes(512))
        self.payload=bytes(range(256))*2
        self.plan=self.card.plan(500,self.payload)
    def test_plan_does_not_write(self):
        self.assertEqual(self.card.write_count,0)
        self.assertEqual(self.card.read(500),bytes(512))
    def test_mock_commit_and_verify(self):
        result=self.card.commit(self.plan,self.payload,acknowledged=True)
        self.assertEqual(result,sha(self.payload))
        self.assertEqual(self.card.write_count,1)
    def test_without_ack(self):
        with self.assertRaises(WriteRejected):
            self.card.commit(self.plan,self.payload)
        self.assertEqual(self.card.write_count,0)
    def test_stale_preimage(self):
        self.card.sector=b"Q"*512
        with self.assertRaisesRegex(WriteRejected,"preimage"):
            self.card.commit(self.plan,self.payload,acknowledged=True)
        self.assertEqual(self.card.write_count,0)
    def test_wrong_lba_card_payload(self):
        with self.assertRaises(WriteRejected):self.card.plan(0,self.payload)
        other=MockCard("DIFFERENT",500,bytes(512))
        with self.assertRaisesRegex(WriteRejected,"identity"):
            other.commit(self.plan,self.payload,acknowledged=True)
        with self.assertRaisesRegex(WriteRejected,"payload"):
            self.card.commit(self.plan,b"Z"*512,acknowledged=True)
        self.assertEqual(self.card.write_count,0)

if __name__=="__main__":unittest.main()

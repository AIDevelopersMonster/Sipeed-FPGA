"""Map guard positive and negative cases, no serial or FPGA."""
import pathlib
import sys
import tempfile
import unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'tools'))
from soc_map_guard import certify, MapGuardError

CSV = '''csr_base,uart,0xf0003000,,
csr_register,uart_rxtx,0xf0003000,1,rw
csr_register,uart_txfull,0xf0003004,1,ro
csr_register,uart_rxempty,0xf0003008,1,ro
memory_region,main_ram,0x40000000,0x4000000,
memory_region,video,0xb1000000,0x100,
'''

class MapGuardTests(unittest.TestCase):
    def check(self, text):
        with tempfile.TemporaryDirectory() as td:
            p=pathlib.Path(td)/'csr.csv'
            p.write_text(text, encoding='utf-8')
            return certify(p)
    def test_valid_map(self):
        item=self.check(CSV)
        self.assertEqual(item['status'],'MAP_STRUCTURE_PASS_NOT_BOARD_PASS')
        self.assertEqual(item['uart_base'],0xf0003000)
        self.assertEqual(item['entry'],0x40010000)
    def test_wrong_uart_or_register(self):
        for c in (CSV.replace('0xf0003004','0xf0003404'),
                  CSV.replace('csr_base,uart,','csr_base,other,'),
                  CSV.replace('uart_rxempty','uart_something_else')):
            with self.subTest(c=c[:35]),self.assertRaises(MapGuardError):self.check(c)
    def test_wrong_video_and_unsafe_ram(self):
        for c in (CSV.replace('0xb1000000','0xb2000000'),
                  CSV.replace('0x4000000,','0x10000,'),
                  CSV.replace('main_ram','spiflash'),
                  CSV+'memory_region,surprise,0x4001a000,0x1000,\n'):
            with self.subTest(c=c[-55:]),self.assertRaises(MapGuardError):self.check(c)
    def test_duplicate_rejected(self):
        with self.assertRaises(MapGuardError):self.check(CSV+'csr_base,uart,0xf0003000,,\n')

if __name__=='__main__':unittest.main()

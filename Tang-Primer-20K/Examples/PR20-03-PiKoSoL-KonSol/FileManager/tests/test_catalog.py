from pathlib import Path
import tempfile
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from pikosol_catalog import make_catalog, find_generated

class TestCatalog(unittest.TestCase):
    def test_unique_names_and_prefer_generated(self):
        with tempfile.TemporaryDirectory() as tmp:
            base=Path(tmp); firmware=base/'firmware'; generated=base/'generated'
            firmware.mkdir(); generated.mkdir()
            (firmware/'demo.bin').write_bytes(b'DEMO')
            (firmware/'monitor.bin').write_bytes(b'MON')
            (firmware/'TP20_HDMI_GRID.bin').write_bytes(b'OLD')
            (generated/'TP20_HDMI_GRID.bin').write_bytes(b'NEW')
            (generated/'TP20_HDMI_COLOR16.bin').write_bytes(b'COL')
            got=make_catalog(firmware,generated,demo=firmware/'demo.bin')
            names=[v.name.casefold() for v in got.values()]
            self.assertEqual(len(names),len(set(names)))
            self.assertEqual(len(names),3)
            self.assertNotIn('monitor.bin',names)
            self.assertEqual(next(v for v in got.values() if v.name=='TP20_HDMI_GRID.bin').read_bytes(),b'NEW')
    def test_explicit_user_choice_and_hide(self):
        with tempfile.TemporaryDirectory() as tmp:
            base=Path(tmp); firmware=base/'firmware'; gen=base/'gen'; outside=base/'outside'
            firmware.mkdir(); gen.mkdir(); outside.mkdir()
            demo=firmware/'demo.bin'; demo.write_bytes(b'X')
            f=gen/'grid.bin'; f.write_bytes(b'OLD')
            replacement=outside/'grid.bin'; replacement.write_bytes(b'NEW')
            got=make_catalog(firmware,gen,demo=demo,pinned=[replacement])
            self.assertEqual(len(got),2)
            self.assertIn(str(replacement.resolve()),got)
            hidden=make_catalog(firmware,gen,demo=demo,pinned=[replacement],hidden=['GRID.bin'])
            self.assertEqual(len(hidden),1)
            self.assertIn(str(demo.resolve()),hidden)

if __name__=='__main__': unittest.main()

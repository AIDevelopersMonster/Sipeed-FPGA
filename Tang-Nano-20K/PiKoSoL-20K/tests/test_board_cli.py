"""End-to-end live-option tests with a serial emulator; no real COM/FPGA."""
import contextlib
import hashlib
import io
import pathlib
import sys
import tempfile
import types
import unittest
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'tools'))
from board_accept import main
from write_build_manifest import make_manifest
import json
from test_board_accept import FakeLiteX
from test_soc_map_guard import CSV

class OpenableFake(FakeLiteX):
    def __enter__(self): return self
    def __exit__(self,*args):pass

class CliTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        root=pathlib.Path(self.directory.name)
        self.csr=root/'csr.csv';self.csr.write_text(CSV)
        self.image=root/'pikosol20k.bin';self.image.write_bytes(b'\x13\x00\x00\x00\xAA')
        self.build_manifest=root/'pikosol20k_build.json'
        self.build_manifest.write_text(json.dumps(make_manifest(self.image,0xF0003000)))
        self.hash_file=root/'pikosol20k.sha256'
        self.hash_file.write_text(hashlib.sha256(self.image.read_bytes()).hexdigest()+'  build/pikosol20k.bin\n')
        self.receipt=root/'receipt.json'
        self.args=['--csr-csv',str(self.csr),'--image',str(self.image),
                   '--hash-file',str(self.hash_file),'--build-manifest',str(self.build_manifest),
                   '--receipt',str(self.receipt)]
        self.old_serial=sys.modules.get('serial')
    def tearDown(self):
        if self.old_serial is None:sys.modules.pop('serial',None)
        else:sys.modules['serial']=self.old_serial
        self.directory.cleanup()
    def simulate(self,flag,fake=None):
        t=fake or OpenableFake()
        class FakeSerial:
            @staticmethod
            def Serial(*a,**kw):return t
        sys.modules['serial']=FakeSerial
        o=io.StringIO(); e=io.StringIO()
        with contextlib.redirect_stdout(o),contextlib.redirect_stderr(e):
            code=main(self.args+flag)
        import json
        report=json.loads(self.receipt.read_text())
        return code,report,t,o.getvalue(),e.getvalue()
    def test_probe_only(self):
        code,r,t,_,_=self.simulate(['--probe'])
        self.assertEqual(code,0);self.assertEqual(r['status'],'V201_PROBE_PASS')
        self.assertTrue(all(x.startswith('mem_read') or x=='' for x in t.sent))
    def test_upload_and_verify_are_distinct(self):
        code,r,t,_,_=self.simulate(['--upload'])
        self.assertEqual(code,0)
        self.assertEqual(r['status'],'SDRAM_READBACK_PASS')
        self.assertTrue(any(x.startswith('mem_write') for x in t.sent))
        self.assertFalse(any(x.startswith('boot') for x in t.sent))
        # A freshly created emulator has no payload. Verify-only must fail.
        code,r,t,_,_=self.simulate(['--verify-only'])
        self.assertEqual(code,2);self.assertEqual(r['status'],'STOP')
        self.assertFalse(any(x.startswith('mem_write') for x in t.sent))
    def test_explicit_boot_with_handshake(self):
        code,r,t,_,_=self.simulate(['--upload','--boot','--confirm-boot'])
        self.assertEqual(code,0)
        self.assertEqual(r['status'],'UART_SHELL_PROMPT_OBSERVED_NOT_HDMI_PASS')
        self.assertEqual(len([x for x in t.sent if x.startswith('boot')]),1)
    def test_wrong_image_hash_blocks_serial(self):
        self.hash_file.write_text('0'*64+'  build/pikosol20k.bin\n')
        code,r,t,_,_=self.simulate(['--upload'])
        self.assertEqual(code,2);self.assertEqual(r['status'],'STOP')
        self.assertEqual(t.sent,[])
    def test_bad_id_blocks_sdram_writes(self):
        code,r,t,_,_=self.simulate(['--upload'],OpenableFake(signature=0))
        self.assertEqual(code,2);self.assertEqual(r['status'],'STOP')
        self.assertFalse(any(x.startswith('mem_write') for x in t.sent))
    def test_mismatched_uart_build_blocks_connection(self):
        data=json.loads(self.build_manifest.read_text())
        data['uart_base']=0xF0003800
        self.build_manifest.write_text(json.dumps(data))
        code,r,t,_,_=self.simulate(['--upload'])
        self.assertEqual(code,2);self.assertEqual(r['status'],'STOP')
        self.assertIn('build manifest',r['error'])
        self.assertEqual(t.sent,[])
    def test_bad_map_blocks_connection(self):
        self.csr.write_text(CSV.replace('0xb1000000','0xb2000000'))
        code,r,t,_,_=self.simulate(['--upload'])
        self.assertEqual(code,2);self.assertEqual(r['status'],'STOP')
        self.assertEqual(t.sent,[])

if __name__=='__main__':unittest.main()

"""Real acceptance FSM with a fake LiteX UART stream; no physical board/COM."""
import contextlib
import io
import pathlib
import sys
import tempfile
import unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'tools'))
from board_accept import Bios, BoardStop, parse_dump, padded_image, main

class FakeLiteX:
    def __init__(self, signature=0x56323031, version=0x10000, busy=False, corrupt=False):
        self.mem={}
        self.signature=signature
        self.version=version
        self.busy=busy
        self.corrupt=corrupt
        self.sent=[]
        self.rx=bytearray()
    def reset_input_buffer(self):
        self.rx.clear()
    def flush(self):
        pass
    def write(self,data):
        command=data.decode('ascii').strip()
        self.sent.append(command)
        output=command+'\r\n'
        if command.startswith('mem_read '):
            _,a,s=command.split()
            addr=int(a,16);count=int(s)
            content=[]
            for i in range(count):
                absolute=addr+i
                if 0xB1000000<=absolute<0xB1000020:
                    offset=(absolute-0xB1000000)//4
                    value={0:self.signature,5:int(self.busy),7:self.version}.get(offset,0)
                    content.append((value>>((absolute%4)*8))&255)
                else:
                    content.append(self.mem.get(absolute,0))
            if self.corrupt and addr>=0x40010000:content[0]^=1
            output+='Memory dump: 0x%08x  '%addr + ' '.join('%02x'%b for b in content)+'  ................\r\n'
        elif command.startswith('mem_write '):
            _,a,v=command.split()
            addr=int(a,16);val=int(v,16)
            for i in range(4):self.mem[addr+i]=(val>>(8*i))&255
        elif command.startswith('boot '):
            output+='\r\nPiKoSoL20K> '
            self.rx.extend(output.encode('ascii'))
            return
        output+='\x1b[92;1mlitex\x1b[0m> '
        self.rx.extend(output.encode('ascii'))
    def read(self,n):
        if not self.rx:return b''
        batch=bytes(self.rx[:min(n,7)])
        del self.rx[:len(batch)]
        return batch

class BoardGateTests(unittest.TestCase):
    def test_flattened_crlf_ansi_and_parser_negative(self):
        good='mem_read 0x40010000 4 Memory dump: 0x40010000  37 34 00 F0  74.. litex>'
        self.assertEqual(parse_dump(good,0x40010000,4),b'\x37\x34\x00\xf0')
        for s in (good.replace('Memory dump:', 'Other:'), good.replace('0x40010000  ', '0x40020000  ')):
            with self.assertRaises(BoardStop):parse_dump(s,0x40010000,4)
    def test_read_only_probe_no_writes(self):
        t=FakeLiteX(); b=Bios(t,1)
        self.assertEqual(b.probe_v201()['id'],'0x56323031')
        self.assertTrue(all(x.startswith('mem_read ') for x in t.sent))
    def test_bad_id_version_busy_stop(self):
        for t in (FakeLiteX(signature=0),FakeLiteX(version=2),FakeLiteX(busy=True)):
            with self.subTest(t=t),self.assertRaises(BoardStop):Bios(t,1).probe_v201()
            self.assertFalse(any(x.startswith('mem_write') for x in t.sent))
    def test_upload_full_readback_and_optin_boot(self):
        t=FakeLiteX(); b=Bios(t,1)
        data=padded_image(b'\x93\x00\x10\x00\xAA')
        b.probe_v201();b.upload(data)
        self.assertTrue(any(x.startswith('mem_write 0x40010004') for x in t.sent))
        self.assertFalse(any(x.startswith('boot ') for x in t.sent))
        self.assertEqual(b.mem_read(0x40010004,4),b'\xaa\x00\x00\x00')
        self.assertIn('PiKoSoL20K>',b.command('boot 0x40010000','PiKoSoL20K>'))
    def test_corrupted_memory_rejected(self):
        t=FakeLiteX(corrupt=True); b=Bios(t,1)
        with self.assertRaisesRegex(BoardStop,'READBACK mismatch'):
            b.upload(padded_image(b'\x01\x02\x03\x04'))
        self.assertFalse(any(x.startswith('boot ') for x in t.sent))
    def test_unknown_command_blocked(self):
        t=FakeLiteX();b=Bios(t,1)
        for cmd in ('flash 0','mem_write 0xB1000000 0x00000001',
                    'mem_write 0xF0003000 0x00000001',
                    'mem_write 0x4001C000 0x00000000',
                    'boot 0x12345678','mem_read 0xB1000000 256',
                    'mem_read 0xF0003000 4'):
            with self.subTest(cmd=cmd), self.assertRaises(BoardStop):b.command(cmd)
        self.assertEqual(t.sent, [])
    def test_default_command_does_not_need_pyserial_or_map(self):
        out=io.StringIO()
        with contextlib.redirect_stdout(out):self.assertEqual(main([]),0)
        self.assertIn('OFFLINE ONLY',out.getvalue())

if __name__=='__main__':unittest.main()

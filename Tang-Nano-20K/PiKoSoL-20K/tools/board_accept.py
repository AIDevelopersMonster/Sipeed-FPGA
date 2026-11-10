#!/usr/bin/env python3
"""P20-SHELL-01 board gates: read-only probe -> SDRAM upload/readback -> opt-in boot.

DEFAULT: OFFLINE plan only; never opens serial port without --probe/--verify-only/--upload.
No FPGA/JTAG/Flash writes are implemented. Hardware operator retains control.
Requires pyserial only for a live COM action, not for tests or dry-run.
"""
import argparse
import hashlib
import json
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from soc_map_guard import certify, MapGuardError, ENTRY, STACK_END, VIDEO_BASE
from write_build_manifest import make_manifest

EXPECTED_VIDEO_ID = 0x56323031
EXPECTED_VIDEO_VERSION = 0x00010000
ANSI_RE = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')
PROMPT = 'litex>'
SHELL_PROMPT = 'PiKoSoL20K>'
BAD_RESPONSE = re.compile(r'(?i)unknown command|incorrect|access fault|bus error|exception|invalid command|unhandled trap')


class BoardStop(RuntimeError):
    pass


def parse_dump(response: str, address: int, size: int) -> bytes:
    if not (1 <= size <= 16):
        raise BoardStop('readback block size must be 1..16')
    marker = re.search(r'Memory dump:', response, re.I)
    if not marker:
        raise BoardStop('BIOS response has no Memory dump header')
    after = response[marker.end():]
    adr = f'0x{address:08x}'
    pattern = re.compile(re.escape(adr) + r'[ \t]{2,}(?P<hex>(?:[0-9a-fA-F]{2}[ \t]+){'
                         + str(size-1) + r'}[0-9a-fA-F]{2})(?![0-9a-fA-F])', re.I)
    match = pattern.search(after)
    if not match:
        raise BoardStop(f'readback address/length mismatch at {adr}, length={size}: {after[:140]!r}')
    raw = re.findall(r'[0-9a-fA-F]{2}', match.group('hex'))
    if len(raw) != size:
        raise BoardStop(f'wrong byte count at {adr}')
    return bytes(int(s, 16) for s in raw)


def padded_image(raw: bytes) -> bytes:
    if not raw or ENTRY + len(raw) > STACK_END - 0x4000:
        raise BoardStop('empty or oversized image: overlaps 16KiB reserved stack')
    return raw + b'\0' * ((-len(raw)) % 4)


class Bios:
    def __init__(self, stream, timeout_s: float = 8.0):
        self.stream = stream
        self.timeout_s = timeout_s

    def wait_for(self, needle: str, timeout_s=None) -> str:
        deadline = time.monotonic() + (timeout_s or self.timeout_s)
        data = bytearray()
        while time.monotonic() < deadline:
            part = self.stream.read(4096)
            if part:
                data.extend(part)
                if len(data) > 150000:
                    raise BoardStop('unexpectedly large BIOS response')
                plain = ANSI_RE.sub('', data.decode('latin1'))
                if needle in plain:
                    return plain
            else:
                time.sleep(0.008)
        raise BoardStop(f'timeout waiting for {needle!r}; output={ANSI_RE.sub("", data.decode("latin1"))[-256:]!r}')

    def command(self, line: str, expect_prompt: str = PROMPT) -> str:
        if not re.fullmatch(r'(?:|mem_read 0x[0-9A-Fa-f]{8} [0-9]{1,2}|mem_write 0x[0-9A-Fa-f]{8} 0x[0-9A-Fa-f]{8}|boot 0x40010000)', line):
            raise BoardStop(f'command not on allowlist: {line!r}')
        # Defense in depth: never allow a caller to convert a RAM write into
        # a Wishbone video write, UART CSR write, Boot ROM write, or Flash write.
        if line.startswith(('mem_read ', 'mem_write ')):
            words = line.split()
            address = int(words[1], 16)
            if words[0] == 'mem_write':
                if not (ENTRY <= address <= STACK_END - 0x4000 - 4 and address % 4 == 0):
                    raise BoardStop(f'non-SDRAM write rejected: 0x{address:08X}')
            else:
                count = int(words[2])
                video_read = (count == 4 and address in (VIDEO_BASE, VIDEO_BASE+0x14, VIDEO_BASE+0x1C))
                ram_read = (1 <= count <= 16 and ENTRY <= address and address + count <= STACK_END-0x4000)
                if not (video_read or ram_read):
                    raise BoardStop(f'non-allowlisted read rejected: 0x{address:08X}/{count}')
        self.stream.reset_input_buffer()
        self.stream.write((line + '\r').encode('ascii'))
        self.stream.flush()
        text = self.wait_for(expect_prompt, 16.0 if line.startswith('boot') else None)
        if BAD_RESPONSE.search(text):
            raise BoardStop(f'BIOS rejected command: {line}; {text[-200:]!r}')
        return text

    def mem_read(self, address: int, size: int) -> bytes:
        return parse_dump(self.command(f'mem_read 0x{address:08X} {size}'), address, size)

    def probe_v201(self) -> dict:
        identity = int.from_bytes(self.mem_read(VIDEO_BASE, 4), 'little')
        if identity != EXPECTED_VIDEO_ID:
            raise BoardStop(f'V201 signature mismatch: 0x{identity:08X}, STOP before SDRAM or VIDEO writes')
        version = int.from_bytes(self.mem_read(VIDEO_BASE + 0x1C, 4), 'little')
        if version != EXPECTED_VIDEO_VERSION:
            raise BoardStop(f'V201 RTL version mismatch: 0x{version:08X}')
        status = int.from_bytes(self.mem_read(VIDEO_BASE + 0x14, 4), 'little')
        if status & 1:
            raise BoardStop(f'V201 BUSY=1: 0x{status:08X}, STOP')
        return {'id': f'0x{identity:08X}', 'version': f'0x{version:08X}',
                'status': f'0x{status:08X}'}

    def readback(self, payload: bytes, origin: int = ENTRY, progress=None) -> None:
        for off in range(0, len(payload), 16):
            chunk = payload[off:off+16]
            actual = self.mem_read(origin + off, len(chunk))
            if chunk != actual:
                for i, (a,b) in enumerate(zip(chunk,actual)):
                    if a != b:
                        raise BoardStop(f'SDRAM READBACK mismatch at 0x{origin+off+i:08X}: expected {a:02X}, received {b:02X}')
                raise BoardStop(f'SDRAM chunk mismatch at 0x{origin+off:08X}')
            if progress and ((off//16 + 1) % 32 == 0 or off+16 >= len(payload)):
                progress(f'READBACK {min(off+16, len(payload))}/{len(payload)} bytes')

    def upload(self, payload: bytes, origin: int = ENTRY, progress=None) -> None:
        if len(payload) % 4:
            raise BoardStop('unaligned image')
        for off in range(0,len(payload),4):
            word = int.from_bytes(payload[off:off+4],'little')
            self.command(f'mem_write 0x{origin+off:08X} 0x{word:08X}')
            if progress and ((off//4 + 1) % 128 == 0 or off+4 >= len(payload)):
                progress(f'RAM WRITE {off+4}/{len(payload)} bytes')
        # Every byte is compared BEFORE execution.
        self.readback(payload, origin, progress)


def expected_hash(path: Path) -> str:
    tokens = path.read_text(encoding='ascii').split()
    if len(tokens) != 2 or not re.fullmatch('[0-9a-fA-F]{64}',tokens[0]):
        raise BoardStop('malformed SHA256 manifest')
    if Path(tokens[1]).name != 'pikosol20k.bin':
        raise BoardStop('SHA256 manifest refers to another image')
    return tokens[0].lower()


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    action=ap.add_mutually_exclusive_group()
    action.add_argument('--probe', action='store_true', help='read BIOS prompt and V201 signature/status/version only')
    action.add_argument('--upload', action='store_true', help='SDRAM writes then complete readback (no boot by default)')
    action.add_argument('--verify-only', action='store_true', help='readback SDRAM only, no writes')
    ap.add_argument('--boot', action='store_true', help='start RAM code after successful --upload and full verification')
    ap.add_argument('--confirm-boot', action='store_true', help='explicit acknowledgement that physical RESET is needed to return to BIOS')
    ap.add_argument('--port', default='COM25')
    ap.add_argument('--csr-csv', type=Path, help='actual EX20-05.16 generated csr.csv (mandatory for live action)')
    ap.add_argument('--image', type=Path, default=Path('build/pikosol20k.bin'))
    ap.add_argument('--hash-file', type=Path, default=Path('build/pikosol20k.sha256'))
    ap.add_argument('--build-manifest', type=Path, default=Path('build/pikosol20k_build.json'))
    ap.add_argument('--receipt', type=Path, help='write JSON receipt including failure state')
    args=ap.parse_args(argv)
    live=args.probe or args.upload or args.verify_only
    if args.boot and not (args.upload and args.confirm_boot):
        ap.error('--boot requires BOTH --upload and --confirm-boot')
    if args.confirm_boot and not args.boot:
        ap.error('--confirm-boot requires --boot')
    if not live:
        print('OFFLINE ONLY: no COM, SDRAM, MMIO, JTAG, FPGA or Flash operations.')
        print('1) python tools/soc_map_guard.py "<EX20-05.16 build/csr.csv>"')
        print('2) ./tools/build_rv32.sh <UART_BASE_FROM_CSV>')
        print('3) python tools/board_accept.py --probe --csr-csv "<csr.csv>" --port COM25')
        print('4) python tools/board_accept.py --upload --csr-csv "<csr.csv>" --port COM25')
        print('5) Manual operator: boot 0x40010000, inspect UART + HDMI, physical RESET.')
        return 0
    if not args.csr_csv:
        ap.error('--csr-csv is mandatory for every live COM operation')
    report = {'tool': 'P20-SHELL-01 / v0.2.0 acceptance gate',
              'time_utc': datetime.now(timezone.utc).isoformat(),
              'status': 'NOT_STARTED', 'operation': 'PROBE' if args.probe else 'UPLOAD' if args.upload else 'VERIFY_ONLY',
              'port': args.port, 'no_flash_operations': True}
    try:
        m = certify(args.csr_csv)
        report['soc_map']=m
        if not args.probe:
            image=args.image.read_bytes()
            sha=hashlib.sha256(image).hexdigest()
            if sha != expected_hash(args.hash_file):
                raise BoardStop('image hash mismatch: rebuild firmware before any writes')
            build_info = json.loads(args.build_manifest.read_text(encoding='utf-8'))
            expected_info = make_manifest(args.image, m['uart_base'])
            if build_info != expected_info:
                raise BoardStop('RV32 build manifest does not match actual UART map or image: REBUILD')
            payload=padded_image(image)
            report.update(image_sha256=sha,image_bytes=len(image),ram_bytes=len(payload),
                          firmware_uart_base=f'0x{m["uart_base"]:08X}',entry=f'0x{ENTRY:08X}')
        else:
            payload=b''
        # Import only after offline validation; pyserial is not needed for dry-run/tests.
        try:
            import serial
        except ImportError as exc:
            raise BoardStop('pyserial is required for live COM: python -m pip install pyserial') from exc
        print(f'Connecting {args.port}; verify correct already-configured EX20-05.16 first')
        with serial.Serial(args.port,115200,timeout=0,write_timeout=8,exclusive=None) as transport:
            bios=Bios(transport)
            bios.command('')   # probe valid LiteX BIOS prompt (ANSI colors accepted)
            report['video']=bios.probe_v201()
            report['status']='V201_PROBE_PASS'
            print('V201 PROBE PASS: ID/version/status; NO VIDEO REGISTERS WRITTEN')
            if args.verify_only:
                bios.readback(payload,progress=print)
                report['status']='SDRAM_READBACK_PASS'
                print('SDRAM READBACK PASS: no SDRAM writes or boot')
            elif args.upload:
                bios.upload(payload,progress=print)
                report['status']='SDRAM_READBACK_PASS'
                print('SDRAM UPLOAD+READBACK PASS, BIOS remains active.')
                if args.boot:
                    print('EXPLICIT BOOT: shell will not return to LiteX BIOS without physical RESET')
                    report['status']='SDRAM_VERIFIED_BOOT_REQUESTED'
                    response=bios.command('boot 0x40010000',SHELL_PROMPT)
                    report['status']='UART_SHELL_PROMPT_OBSERVED_NOT_HDMI_PASS'
                    report['uart_tail']=response[-1500:]
                    print('UART SHELL PROMPT OBSERVED. Operator must test commands/HDMI and record evidence.')
        return 0
    except (BoardStop,MapGuardError,OSError,ValueError) as exc:
        report['status']='STOP'
        report['error']=str(exc)
        print(f'ACCEPTANCE STOP: {exc}',file=sys.stderr)
        return 2
    finally:
        if args.receipt:
            args.receipt.parent.mkdir(parents=True,exist_ok=True)
            args.receipt.write_text(json.dumps(report, indent=2)+'\n',encoding='utf-8')


if __name__=='__main__':
    raise SystemExit(main())

#!/usr/bin/env python3
"""Negative and positive contract cases for strict T3 ASCII decoder (no RTL claims)."""
from lab03_trace_decode import decode, read_rom
from pathlib import Path

root = Path(__file__).resolve().parents[1]
rom = read_rom(root/'firmware'/'lab03_boot.hex')


def must_fail(text: str, label: str, allow_incomplete: bool = False) -> None:
    try:
        decode(text, rom, require_complete=not allow_incomplete)
    except ValueError:
        return
    raise AssertionError(f'should reject {label}')


def main() -> None:
    status = (3 << 24) | (128 << 16) | 0x100 | 2
    good = (f'T3:{status:08x}:00000034\n'
            f'E:00000000:00010001:00000000:{rom[0]:08x}\n'
            f'E:00000001:00020002:20000000:00000008\nZ\n')
    snap = decode(good,rom)
    assert snap['count'] == 2 and snap['events'][-1]['value'] == '0x00000008'
    must_fail(good.replace('E:00000001:', 'E:00000002:'),'skipped index')
    must_fail(good.replace(f'{rom[0]:08x}', 'ffffffff'),'wrong ROM word')
    must_fail(good.replace('00000008\nZ','00000001\nZ'),'wrong LED bit')
    must_fail(good.replace('20000000:', '20000004:'),'wrong MMIO address')
    must_fail(good.replace('Z\n',''),'missing Z')
    must_fail(good.replace(f'{status:08x}',f'{status|0x200:08x}'),'truncated flag')
    must_fail(good.replace(f'{status:08x}',f'{status|0x400:08x}'),'overlap flag')
    must_fail(good.replace(f'{status:08x}',f'{status&~0x100:08x}'),'missing done flag')
    must_fail(good.replace('T3:', 'T4:'),'bad protocol version')
    must_fail(good.replace('E:00000001:', 'E:00000000:'),'duplicate index')
    assert decode(good.replace(f'{status:08x}',f'{status|0x200:08x}'),rom,require_complete=False)['flags']['truncated']
    print('LAB03_2_PROTOCOL_PARSER_PASS: framing, count, index, ROM, MMIO, flags, version, incomplete mode')

if __name__=='__main__':main()

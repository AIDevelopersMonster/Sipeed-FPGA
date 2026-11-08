#!/usr/bin/env python3
"""LAB20.6 offline RV32I/CSR instruction simulator, independent of hardware.

Verifies: first UART TX happens only AFTER all 11 CSR snapshots are stored;
loader code has no Flash write; output matches memory pre-print samples.
Only subset of RV32I needed by this exact binary is implemented.
"""
from pathlib import Path
import re, hashlib, json
BASE=0x40010000
SDRAM=0x40000000
UART=0xF0003000
SNAP=0x40011000
ROOT=Path(__file__).resolve().parent
BIN=(ROOT/'snapshot.bin').read_bytes()
MAN=json.loads((ROOT/'manifest.json').read_text())
assert hashlib.sha256(BIN).hexdigest() == MAN['bin_sha256']
assert len(BIN)==MAN['image_bytes'] and len(BIN)%4==0 and len(BIN)<4096
LOAD=(ROOT/'load_mem_write_only.txt').read_text().splitlines()
assert len(LOAD)==len(BIN)//4
for i,line in enumerate(LOAD):
    m=re.fullmatch(r'mem_write 0x([0-9A-F]{8}) 0x([0-9A-F]{8})',line)
    assert m, line
    assert int(m[1],16)==BASE+i*4
    assert int(m[2],16)==int.from_bytes(BIN[i*4:i*4+4],'little')
    assert '0x40010000' <= f'0x{int(m[1],16):08x}' < '0x40011000'

U32=0xffffffff

def sext(x,bits):
    mask=(1<<bits)-1
    x &= mask
    return x-(1<<bits) if x&(1<<(bits-1)) else x

def run(txempty_at_start):
    ram=bytearray(0x20000)
    ram[BASE-SDRAM:BASE-SDRAM+len(BIN)]=BIN
    r=[0]*32
    csr={0x300:0x1800,0x304:0x880,0xBC0:0,0xFC0:0}
    uart_state={4:0,8:1,12:1,16:0,20:3,24:txempty_at_start,28:0}
    pc=BASE
    bytes_sent=bytearray()
    txfirst_step=None
    total_reads=0
    for tick in range(2_300_000):
        if b'LAB20.6 HOLD - press physical RESET to return to BIOS\r\n' in bytes_sent and int.from_bytes(ram[pc-SDRAM:pc-SDRAM+4],'little')==0x0000006f:
            break
        assert BASE <= pc < BASE+len(BIN),f'invalid PC 0x{pc:08x}'
        off=pc-SDRAM
        w=int.from_bytes(ram[off:off+4],'little')
        if w&3 != 3: raise AssertionError(f'RVC not expected 0x{w:08x}')
        op=w&0x7f
        rd=(w>>7)&31
        f3=(w>>12)&7
        rs1=(w>>15)&31
        rs2=(w>>20)&31
        nextpc=(pc+4)&U32
        def read(address,width):
            nonlocal total_reads
            total_reads+=1
            if UART<=address<UART+32:
                assert width==4 and (address-UART)%4==0
                return uart_state[address-UART]
            if not SDRAM<=address<SDRAM+len(ram)-width+1:raise AssertionError(f'Invalid read 0x{address:08x}')
            offset=address-SDRAM
            return int.from_bytes(ram[offset:offset+width],'little')
        def write(address,value,width):
            nonlocal txfirst_step
            if UART<=address<UART+32:
                assert address==UART and width==4, f'Only UART data writes allowed: 0x{address:08x}'
                if txfirst_step is None:
                    txfirst_step=tick
                    assert int.from_bytes(ram[SNAP-SDRAM+52:SNAP-SDRAM+56],'little')==0x454e4f44,'UART transmit started before snapshot finished'
                bytes_sent.append(value&255)
                uart_state[24]=0 # FIFO considered busy after first write
                return
            assert SNAP<=address<SNAP+60 and width==4, f'Unexpected write 0x{address:08x}'
            offset=address-SDRAM
            ram[offset:offset+width]=(value&U32).to_bytes(width,'little')
        if op==0x37:r[rd]=w&0xfffff000
        elif op==0x17:r[rd]=(pc+(w&0xfffff000))&U32
        elif op==0x13:
            imm=sext(w>>20,12)
            if f3==0:r[rd]=(r[rs1]+imm)&U32
            elif f3==1:r[rd]=(r[rs1] << ((w>>20)&31))&U32
            elif f3==5:r[rd]=(r[rs1] >> ((w>>20)&31))&U32
            else:raise AssertionError(f'OPIMM funct3={f3}')
        elif op==0x03:
            address=(r[rs1]+sext(w>>20,12))&U32
            if f3==2:r[rd]=read(address,4)
            elif f3==4:r[rd]=read(address,1)
            else:raise AssertionError('unsupported LOAD')
        elif op==0x23:
            imm=sext(((w>>25)<<5)|((w>>7)&31),12)
            assert f3==2,'unsupported STORE'
            write((r[rs1]+imm)&U32,r[rs2],4)
        elif op==0x63:
            imm=sext((((w>>31)&1)<<12)|(((w>>7)&1)<<11)|(((w>>25)&63)<<5)|(((w>>8)&15)<<1),13)
            take=(f3==0 and r[rs1]==r[rs2]) or (f3==1 and r[rs1]!=r[rs2]) or (f3==6 and r[rs1]<r[rs2])
            assert f3 in (0,1,6)
            if take:nextpc=(pc+imm)&U32
        elif op==0x6f:
            imm=sext((((w>>31)&1)<<20)|(((w>>12)&255)<<12)|(((w>>20)&1)<<11)|(((w>>21)&1023)<<1),21)
            r[rd]=(pc+4)&U32
            nextpc=(pc+imm)&U32
        elif op==0x67:
            assert f3==0
            imm=sext(w>>20,12)
            nextpc=(r[rs1]+imm)&(U32^1)
            r[rd]=(pc+4)&U32
        elif op==0x73:
            assert f3==2,'only CSRRS supported'
            c=w>>20
            assert c in csr
            r[rd]=csr[c]
            assert rs1==0,'CSR writes not intended'
        else:raise AssertionError(f'unsupported opcode 0x{op:02x} at pc=0x{pc:08x}')
        r[0]=0
        pc=nextpc
    else:raise AssertionError('Execution timeout or wrong hold loop')
    stored=[int.from_bytes(ram[SNAP-SDRAM+i:SNAP-SDRAM+i+4],'little') for i in range(0,60,4)]
    assert stored[0]==0x504B534C and stored[1]==0x0001000B and stored[13]==0x454E4F44
    expected=[txempty_at_start,0,1,1,0,3,0,0x1800,0x880,0,0]
    assert stored[2:13]==expected, (stored[2:13],expected)
    assert stored[14] == 0, "TXEMPTY after output expected 0 in FIFO-backed mock"
    output=bytes(bytes_sent).decode('ascii')
    labels=['TXEMPTY','TXFULL','RXEMPTY','EV_STATUS','EV_PENDING','EV_ENABLE','RXFULL','MSTATUS','MIE','IRQ_MASK','IRQ_PENDING']
    for label,num in zip(labels,expected):
        regex=rf'(?m)^'+re.escape(label)+r'\s*= 0x'+f'{num:08X}'+r'\r?$'
        assert re.search(regex,output),f'{label} missing in {output}'
    assert output.startswith('\r\nPiKoSoL LAB20.6 RAM-only snapshot BEFORE UART output\r\n')
    assert 'TXEMPTY_AFTER_PRINT = 0x00000000\r\n' in output
    assert output.endswith('LAB20.6 HOLD - press physical RESET to return to BIOS\r\n')
    assert txfirst_step is not None
    print(f'PASS txempty_preprint={txempty_at_start} steps={tick:,}, bytes_TX={len(bytes_sent)}, mmio_reads={total_reads}, snapshot_data_verified=True')
    return output

if __name__=='__main__':
    result=run(1)
    run(0)
    (ROOT/'SIMULATED_OUTPUT.txt').write_text('SIMULATED ONLY - NOT HARDWARE EVIDENCE\n'+result,encoding='utf-8')
    print('PASS binary+commands+memory bounds+all UART text+snapshot-before-print')
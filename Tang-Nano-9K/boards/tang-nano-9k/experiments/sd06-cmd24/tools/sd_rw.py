#!/usr/bin/env python3
"""Standalone Tang Nano 9K SDHC UART client: read, compare-and-swap sector write.

Read commands work with SD-05 and SD-06. Writes require explicitly qualified
SD-06 RW firmware compiled for a single approved scratch LBA; no FAT32 updates.
Never use for a valuable SD card. Python 3.9+ and pyserial for COM access.
"""
import argparse
import hashlib
from pathlib import Path
import sys
import time

def crc16(data):
    c=0xFFFF
    for byte in data:
        c ^= byte<<8
        for _ in range(8):
            c=((c<<1)^(0x1021 if c&0x8000 else 0))&0xFFFF
    return c

def packet(body):
    return body+crc16(body).to_bytes(2,"little")

def read_req(lba,seq):
    return packet(bytes([0xA5,0x52,seq])+lba.to_bytes(4,"little"))

def write_req(lba,seq,old,new):
    if len(old)!=512 or len(new)!=512: raise ValueError("sectors must be exactly 512 bytes")
    return packet(bytes([0xA5,0x57,seq])+lba.to_bytes(4,"little")+old+new)

def parse_reply(frame,seq,lba,expected):
    if len(frame)<10 or frame[0]!=0x5A or frame[1]!=expected:
        raise ValueError("unexpected FPGA reply type/length")
    if frame[-2:]!=crc16(frame[:-2]).to_bytes(2,"little"):
        raise ValueError("reply CRC16 mismatch")
    if frame[2]!=seq or int.from_bytes(frame[3:7],"little")!=lba:
        raise ValueError("reply seq/LBA mismatch")
    if expected==0x44 and len(frame)==523 and frame[7:9]==b"\0\0":
        return frame[9:-2]
    if expected==0x57 and len(frame)==10:
        if frame[7]:raise ValueError("FPGA write error %02X"%frame[7])
        return None
    if expected==0x45 and len(frame)==10:
        raise ValueError("FPGA read error %02X"%frame[7])
    raise ValueError("reply format invalid")

class Transport:
    def __init__(self,name,timeout):
        import serial
        self.conn=serial.Serial(name,115200,timeout=0.1,write_timeout=3,
                                xonxoff=False,rtscts=False,dsrdtr=False)
        self.timeout=timeout
        self.seq=0
        self.conn.reset_input_buffer()
    def close(self):self.conn.close()
    def recv(self,n):
        end=time.monotonic()+self.timeout
        data=bytearray()
        while len(data)<n and time.monotonic()<end:
            data.extend(self.conn.read(n-len(data)))
        if len(data)!=n:raise TimeoutError("reply truncated %d/%d"%(len(data),n))
        return bytes(data)
    def command(self,lba,old=None,new=None):
        self.seq=(self.seq+1)&255
        seq=self.seq
        msg=read_req(lba,seq) if old is None else write_req(lba,seq,old,new)
        if self.conn.write(msg)!=len(msg):raise IOError("partial UART send")
        self.conn.flush()
        head=self.recv(2)
        if head==b"ZD":
            return parse_reply(head+self.recv(521),seq,lba,0x44)
        if head==b"ZE":
            return parse_reply(head+self.recv(8),seq,lba,0x45)
        if head==b"ZW":
            return parse_reply(head+self.recv(8),seq,lba,0x57)
        raise ValueError("invalid FPGA header "+head.hex())
    def read(self,lba):
        result=self.command(lba)
        if not isinstance(result,bytes) or len(result)!=512:
            raise ValueError("read did not return 512-byte sector")
        return result
    def write(self,lba,old,new):
        r=self.command(lba,old,new)
        if r is not None:raise ValueError("unexpected write reply")

def sha(data):return hashlib.sha256(data).hexdigest().upper()

def run():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--port",required=True)
    p.add_argument("--timeout",type=float,default=15)
    sub=p.add_subparsers(dest="cmd",required=True)
    for cmd in ("read","plan","write"):
        q=sub.add_parser(cmd)
        q.add_argument("--lba",required=True,type=lambda s:int(s,0))
        if cmd=="read":q.add_argument("--out",required=True,type=Path)
        else:q.add_argument("--data",required=True,type=Path)
        if cmd=="write":
            q.add_argument("--preimage",required=True,type=Path,
                           help="512-byte backup from a previous read")
            q.add_argument("--expect-sha256",required=True,
                           help="expected sha256 of the original sector")
            q.add_argument("--allow-lba",required=True,type=lambda s:int(s,0))
            q.add_argument("--confirm",required=True,
                           help="must be WRITE-TEST-CARD-LBA-N")
    a=p.parse_args()
    if not 0<=a.lba<=0xffffffff or a.timeout<=0:
        p.error("invalid LBA or timeout")
    if a.cmd in ("plan","write") and len(a.data.read_bytes())!=512:
        p.error("new sector data must have 512 bytes")
    if a.cmd=="write":
        if a.allow_lba!=a.lba or a.lba==0 or a.confirm!=f"WRITE-TEST-CARD-LBA-{a.lba}":
            p.error("explicit allowed LBA/confirmation mismatch")
        old=a.preimage.read_bytes()
        if len(old)!=512 or sha(old)!=a.expect_sha256.upper():
            p.error("preimage length/hash mismatch")
        new=a.data.read_bytes()
    if a.cmd=="plan":
        print("SD_RW_PLAN_ONLY: LBA=%d NEW_SHA256=%s"%(a.lba,sha(a.data.read_bytes())))
        print("Read the sector with --out, back up the entire disposable card, and "
              "use write only after firmware has been configured for a verified scratch LBA.")
        return 0
    if a.cmd=="read" and a.out.exists():
        p.error("destination already exists; refusing overwrite")
    link=Transport(a.port,a.timeout)
    try:
        if a.cmd=="read":
            data=link.read(a.lba)
            with a.out.open("xb") as f:f.write(data)
            print(f"SD_RW_READ_PASS: LBA={a.lba} SHA256={sha(data)}")
        elif a.cmd=="write":
            actual=link.read(a.lba)
            if actual!=old:
                raise ValueError("preimage differs from current card sector; WRITE BLOCKED")
            if actual==new:
                raise ValueError("new data already present; WRITE BLOCKED to avoid unnecessary wear")
            link.write(a.lba,old,new)
            verify=link.read(a.lba)
            if verify!=new:
                raise ValueError("SD_RW_VERIFY_FAIL: readback differs after CMD24")
            print(f"SD_RW_WRITE_VERIFY_PASS: LBA={a.lba} SHA256={sha(verify)}")
    finally:
        link.close()
    return 0

if __name__=="__main__":
    try:raise SystemExit(run())
    except (OSError,ValueError,TimeoutError,ImportError) as e:
        print("SD_RW_FAIL:",e,file=sys.stderr)
        raise SystemExit(1)

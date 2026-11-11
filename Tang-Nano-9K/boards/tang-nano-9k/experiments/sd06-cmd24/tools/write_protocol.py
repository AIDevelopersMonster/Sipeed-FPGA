"""SD-06B offline UART write-frame reference. NEVER opens a serial port.
No existing SD-05 FPGA firmware accepts this command.
A5 57 seq LBA32_LE old_sector_sha256[32] payload[512] CRC16_LE = 553 bytes.
Separate trusted preimage and authorization gate REQUIRED before CMD24.
"""
from dataclasses import dataclass
import hashlib
FRAME_LEN=553
class FrameError(ValueError): pass
def crc16(data):
    c=0xFFFF
    for b in data:
        c ^= b << 8
        for _ in range(8):
            c = (((c<<1) ^ (0x1021 if c & 0x8000 else 0)) & 0xFFFF)
    return c

@dataclass(frozen=True)
class WriteFrame:
    seq: int
    lba: int
    expected_preimage_digest: bytes
    payload: bytes

def encode(seq,lba,preimage,payload):
    if not 0 <= seq <= 255 or not 0 < lba < (1<<32):
        raise FrameError("invalid sequence or LBA")
    if len(preimage)!=512 or len(payload)!=512:
        raise FrameError("preimage and payload must both be 512 bytes")
    body=(bytes([0xA5,0x57,seq])+lba.to_bytes(4,"little")
          +hashlib.sha256(preimage).digest()+bytes(payload))
    return body+crc16(body).to_bytes(2,"little")

def decode(frame):
    if len(frame)!=FRAME_LEN: raise FrameError("invalid frame length")
    if frame[:2]!=bytes([0xA5,0x57]):
        raise FrameError("unsupported command")
    if crc16(frame[:-2])!=int.from_bytes(frame[-2:],"little"):
        raise FrameError("invalid CRC16")
    return WriteFrame(frame[2],int.from_bytes(frame[3:7],"little"),
                      bytes(frame[7:39]),bytes(frame[39:551]))

def would_match_preimage(req,preimage):
    return len(preimage)==512 and hashlib.sha256(preimage).digest()==req.expected_preimage_digest

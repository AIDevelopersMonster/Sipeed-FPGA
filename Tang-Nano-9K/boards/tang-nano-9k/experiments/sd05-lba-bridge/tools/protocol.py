#!/usr/bin/env python3
"""Proposed SD-05 read-only UART wire protocol. No hardware implementation yet."""
from dataclasses import dataclass

class ProtocolError(ValueError):
    pass

def crc16(data: bytes) -> int:
    crc = 0xFFFF
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            crc = ((crc << 1) ^ (0x1021 if crc & 0x8000 else 0)) & 0xFFFF
    return crc

def append_crc(payload: bytes) -> bytes:
    return payload + crc16(payload).to_bytes(2, 'little')

def request(lba: int, seq: int) -> bytes:
    if not 0 <= lba <= 0xFFFFFFFF or not 0 <= seq <= 255:
        raise ProtocolError('LBA or sequence out of range')
    return append_crc(bytes((0xA5, 0x52, seq)) + lba.to_bytes(4, 'little'))

@dataclass(frozen=True)
class Sector:
    seq: int
    lba: int
    data: bytes

def parse_reply(frame: bytes, *, seq: int, lba: int) -> Sector:
    if len(frame) not in (10, 523):
        raise ProtocolError(f'invalid frame length {len(frame)}')
    if frame[0] != 0x5A or frame[1] not in (0x44, 0x45):
        raise ProtocolError('invalid response signature')
    if frame[-2:] != crc16(frame[:-2]).to_bytes(2, 'little'):
        raise ProtocolError('bad CRC16')
    if frame[2] != seq or int.from_bytes(frame[3:7], 'little') != lba:
        raise ProtocolError('stale/wrong LBA response')
    if frame[1] == 0x45:
        if len(frame) != 10:
            raise ProtocolError('invalid error response length')
        raise ProtocolError(f'FPGA SD error {frame[7]:02X}')
    if len(frame) != 523 or frame[7:9] != b'\x00\x00':
        raise ProtocolError('invalid data frame/status')
    return Sector(seq, lba, frame[9:-2])

def synthetic_success(lba: int, seq: int, data: bytes) -> bytes:
    """Fixtures only. Never claim this was received from a card."""
    if len(data) != 512:
        raise ProtocolError('data length must be 512')
    return append_crc(bytes((0x5A, 0x44, seq)) + lba.to_bytes(4, 'little') + b'\x00\x00' + data)

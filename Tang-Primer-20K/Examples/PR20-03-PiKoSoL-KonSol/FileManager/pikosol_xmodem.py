"""Experimental generic RAM app loader (XMODEM-CRC 128), PC-side only.

Do not use for initial board recovery: verified host_console.py handles that.
The algorithm is grounded in THLN33/picoRV32_HDMI src/boot/downloader.c,
System_picoRV32/scripts/downloader.py, and the board-tested monitor command
set. Only the original demo transfer has BOARD PASS; custom files still need a
physical acceptance test. No FPGA configuration programming in this module.
"""
from __future__ import annotations

from dataclasses import dataclass
import re
import time
from typing import Callable

SOH, EOT, ACK, NAK, CAN = 0x01, 0x04, 0x06, 0x15, 0x18
BLOCK = 128


class TransferError(Exception):
    pass


@dataclass(frozen=True)
class DirectResult:
    blocks: int
    acked: int
    ended: bool
    ran: bool
    returned: bool
    output: str


Progress = Callable[[str, int, int], None]
CancelCheck = Callable[[], bool]


def _check_cancel(cancel: CancelCheck | None) -> None:
    if cancel is not None and cancel():
        raise TransferError('OPERATOR CANCEL: PC XMODEM stopped; FPGA LOAD state unknown')



def crc16_ccitt(data: bytes) -> int:
    crc = 0
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            crc = (((crc << 1) ^ 0x1021) if (crc & 0x8000) else (crc << 1)) & 0xffff
    return crc


def frame(block_number: int, payload: bytes) -> bytes:
    if len(payload) > BLOCK or block_number < 1:
        raise ValueError('Invalid XMODEM packet')
    padded = payload.ljust(BLOCK, b'\x00')
    crc = crc16_ccitt(padded)
    n = block_number & 0xff
    return bytes((SOH, n, 0xff - n)) + padded + bytes((crc >> 8, crc & 0xff))


def read_byte_until(ser, timeout: float, cancel: CancelCheck | None = None):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        _check_cancel(cancel)
        data = ser.read(1)
        if data:
            return data[0]
    return None


def wait_for_crc_ready(ser, report: Progress, timeout: float = 10, cancel: CancelCheck | None = None) -> bytes:
    """Wait for a standalone 'C' after sending LOAD, not a 'C' in response text."""
    deadline = time.monotonic() + timeout
    transcript = bytearray()
    while time.monotonic() < deadline:
        _check_cancel(cancel)
        chunk = ser.read(1)
        if not chunk:
            continue
        b = chunk[0]
        transcript.append(b)
        if b == CAN:
            raise TransferError('Target cancelled transfer (CAN)')
        if b == ord('C'):
            # A standalone CRC request has no trailing characters. Printable
            # words (CRC, XMODEM-CRC) do; do not mistake their 'C' for ACK.
            _check_cancel(cancel)
            following = ser.read(1)
            if not following:
                return bytes(transcript)
            transcript.extend(following)
    raise TransferError(f'No XMODEM CRC_READY C in {timeout}s; RX={bytes(transcript[-180:])!r}')


def await_ack_or_nak(ser, timeout: float, transcript: bytearray, cancel: CancelCheck | None = None) -> int:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        _check_cancel(cancel)
        item = ser.read(1)
        if not item:
            continue
        b = item[0]
        if b in (ACK, NAK, CAN):
            return b
        transcript.append(b)
    raise TransferError('ACK/NAK timeout while sending XMODEM')


def read_transcript(ser, duration: float = 0.7, cancel: CancelCheck | None = None) -> bytes:
    deadline = time.monotonic() + duration
    data = bytearray()
    while time.monotonic() < deadline:
        _check_cancel(cancel)
        rx = ser.read(128)
        if rx:
            data.extend(rx)
    return bytes(data)


def send_binary(ser, image: bytes, report: Progress,
                *, handshake_timeout: float = 10.0,
                ack_timeout: float = 4.0, retries: int = 6,
                run_timeout: float = 8.0, cancel: CancelCheck | None = None) -> DirectResult:
    """Send LOAD + XMODEM + RUN using an already-open exclusive serial port.

    No attempt is made to configure FPGA or reset the CPU. A timeout or
    cancellation can leave the monitor in LOAD mode; report it explicitly.
    """
    _check_cancel(cancel)
    if len(image) < 20 or len(image) > 12288 or ((len(image)+127)//128)*128 > 12288:
        raise ValueError('App does not fit the 12 KiB LOAD limit (monitor 0x3000)')
    import struct
    w = struct.unpack_from('<IIII', image)
    if w != (0x31444B50, len(image), 0x2000C010, 0):
        raise ValueError(f'Invalid PiKoSoL PKD1 16-byte header: got={w!r}; '
                         f'expected=(0x31444B50,{len(image)},0x2000C010,0). NO LOAD SENT.')
    total = (len(image)+BLOCK-1)//BLOCK
    raw_output = bytearray()
    _check_cancel(cancel)
    report('LOAD sent', 0, total)
    ser.write(b'LOAD\r')
    ser.flush()
    raw_output.extend(wait_for_crc_ready(ser, report, handshake_timeout, cancel))
    acked = 0
    for index in range(total):
        _check_cancel(cancel)
        pkt = frame(index+1, image[index*BLOCK:(index+1)*BLOCK])
        for attempt in range(retries):
            _check_cancel(cancel)
            ser.write(pkt)
            ser.flush()
            response = await_ack_or_nak(ser, ack_timeout, raw_output, cancel)
            if response == ACK:
                acked += 1
                report('ACK', acked, total)
                break
            if response == CAN:
                raise TransferError(f'FPGA CAN at block {index+1}/{total}')
            report(f'NAK/retry {attempt+1}', acked, total)
        else:
            raise TransferError(f'XMODEM failed at block {index+1}/{total}: {retries} retries')
    _check_cancel(cancel)
    ser.write(bytes((EOT,)))
    ser.flush()
    if await_ack_or_nak(ser, ack_timeout, raw_output, cancel) != ACK:
        raise TransferError('EOT not ACKed')
    load_reply = read_transcript(ser, 0.8, cancel)
    raw_output.extend(load_reply)
    report('EOT ACK', acked, total)
    after_load = load_reply.decode('ascii', errors='replace').upper()
    if re.search(r'\bLOAD\s+(?:BAD|FAIL|ERROR|INVALID|REJECT)', after_load):
        raise TransferError('FPGA rejected LOAD. RUN NOT SENT. RX=' + repr(after_load[-240:]))
    if not re.search(r'\bLOAD\s+(?:OK|PASS|SUCCESS|DONE|COMPLETE)\b', after_load):
        raise TransferError('No explicit FPGA LOAD success confirmation. RUN NOT SENT. RX=' + repr(after_load[-240:]))
    _check_cancel(cancel)  # Never RUN after an operator aborts LOAD
    ser.write(b'RUN\r')
    ser.flush()
    started = time.monotonic()
    seen = bytearray()
    while time.monotonic() - started < run_timeout:
        _check_cancel(cancel)
        item = ser.read(256)
        if item:
            seen.extend(item)
            if b'RUN RETURNED TO PiKoSoL' in seen:
                break
    _check_cancel(cancel)
    raw_output.extend(seen)
    output = bytes(raw_output).decode('ascii', errors='replace')
    ran = b'RUN ' in seen or b'RUN\r' in seen or b'RUN\n' in seen
    returned = b'RUN RETURNED TO PiKoSoL' in seen
    report('RUN RETURNED' if returned else 'RUN unconfirmed', acked, total)
    return DirectResult(total, acked, True, ran, returned, output)

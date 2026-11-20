"""Protocol-independent host helpers for PiKoSoL TP20 File Manager.

Scope: PC files, validation, command construction, and invoking the ALREADY
board-tested local host_console.py. No FPGA programming, no Flash operations.
"""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from datetime import datetime
from typing import Callable, Optional

MONITOR_SHA256 = "414d8b9859ce95826e9a0ba12a26e820af2942cd4fd964ea9ff75ac28ae135c7"
DEMO_SHA256 = "be20fb6ec6d1c7bfe1e9591f0c734649c61d200217f5ebf15800b4f4e681de26"
MONITOR_SIZE = 18560
DEMO_SIZE = 1292
RAM_ORIGIN = 0x20000000
RAM_SIZE = 0x10000
APP_ORIGIN = 0x2000C000
APP_ENTRY = APP_ORIGIN + 0x10
APP_CAPACITY = min(RAM_ORIGIN + RAM_SIZE - APP_ORIGIN, 0x3000)  # LOAD limit: 12 KiB; RAM window: 16 KiB
XMODEM_BLOCK_SIZE = 128


@dataclass(frozen=True)
class Paths:
    root: Path
    host: Path
    monitor: Path
    demo: Path

    @staticmethod
    def from_root(root: Path) -> 'Paths':
        root = root.expanduser().resolve()
        return Paths(root, root / 'tools' / 'host_console.py',
                     root / 'firmware' / 'monitor.bin', root / 'firmware' / 'demo.bin')



def assert_hash_reference_integrity() -> None:
    """Catch typos/truncations in this *program*, not falsely blame user files.

    SHA256.hexdigest() is always 64 lowercase hexadecimal characters.
    """
    for name, value in (("monitor.bin", MONITOR_SHA256), ("demo.bin", DEMO_SHA256)):
        if len(value) != 64 or re.fullmatch(r'[0-9a-f]{64}', value) is None:
            raise RuntimeError(
                f'Ошибка в константе программы: эталон SHA256 {name} '
                f'имеет длину {len(value)} вместо 64. Рабочие файлы не повреждены.'
            )


def baseline_candidates(script_folder: Path) -> list[Path]:
    """Include known original and nested unpacked folders (NO recursive disk scan)."""
    folder = script_folder.expanduser().resolve()
    base = Path.home() / 'Downloads' / 'TP20_PiKoSoL_PicoRV32_UART_HDMI_TEST'
    candidates = [folder, folder.parent, base, base / base.name]
    # Backup extracts may have exactly this directory name in Downloads.
    downloads = Path.home() / 'Downloads'
    try:
        candidates.extend(sorted(p for p in downloads.glob('TP20_PiKoSoL_PicoRV32_UART_HDMI_TEST*') if p.is_dir()))
    except OSError:
        pass
    unique, seen = [], set()
    for path in candidates:
        path = path.resolve()
        if path not in seen:
            seen.add(path)
            unique.append(path)
    return unique


def baseline_is_verified(paths: Paths) -> bool:
    """Only prefer a folder after checking BOTH known binary hashes."""
    assert_hash_reference_integrity()
    try:
        return (paths.host.is_file() and
                paths.monitor.is_file() and paths.monitor.stat().st_size == MONITOR_SIZE and
                sha256_file(paths.monitor) == MONITOR_SHA256 and
                paths.demo.is_file() and paths.demo.stat().st_size == DEMO_SIZE and
                sha256_file(paths.demo) == DEMO_SHA256)
    except OSError:
        return False


def auto_paths(script_folder: Path, root_override: str = '') -> Paths:
    assert_hash_reference_integrity()
    if root_override:
        return Paths.from_root(Path(root_override))
    candidates = baseline_candidates(script_folder)
    for candidate in candidates:
        paths = Paths.from_root(candidate)
        if baseline_is_verified(paths):
            return paths
    # Do not silently trust a wrong monitor; choose the most relevant folder
    # only for a detailed, non-destructive diagnostic at --check / upload time.
    for candidate in candidates:
        if (candidate / 'tools' / 'host_console.py').is_file():
            return Paths.from_root(candidate)
    return Paths.from_root(Path.home() / 'Downloads' / 'TP20_PiKoSoL_PicoRV32_UART_HDMI_TEST')


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(65536), b''):
            digest.update(chunk)
    return digest.hexdigest()


def _verified_file(path: Path, name: str, size: int, digest: str) -> None:
    if not path.is_file():
        raise FileNotFoundError(f'{name} не найден.\nПУТЬ: {path}')
    actual_size = path.stat().st_size
    actual_digest = sha256_file(path)
    if actual_size != size or actual_digest != digest:
        raise ValueError(f'{name} отличается от подтверждённого файла.\n'
                         f'ПУТЬ: {path}\n'
                         f'РАЗМЕР: {actual_size} байт (ожидается {size})\n'
                         f'SHA256 ФАКТ: {actual_digest}\n'
                         f'SHA256 ЭТАЛОН: {digest}\n'
                         'Возможно, выбран другой распакованный комплект. '
                         'Рабочие файлы не перезаписывайте: укажите правильную папку через --root.')


def check_baseline(paths: Paths) -> list[str]:
    assert_hash_reference_integrity()
    if not paths.host.is_file():
        raise FileNotFoundError(f'host_console.py не найден.\nПУТЬ: {paths.host}')
    _verified_file(paths.monitor, 'monitor.bin', MONITOR_SIZE, MONITOR_SHA256)
    _verified_file(paths.demo, 'demo.bin', DEMO_SIZE, DEMO_SHA256)
    return [f'ИСТОЧНИК: {paths.root}', 'host_console.py найден',
            'MONITOR SHA256 PASS', 'DEMO SHA256 PASS']


@dataclass(frozen=True)
class BinaryInfo:
    path: Path
    size: int
    padded_size: int
    blocks: int
    sha256: str
    header: tuple[int, int, int, int]
    demo_magic: int

    def summary(self) -> str:
        h = ', '.join(f'0x{x:08X}' for x in self.header)
        return (f'{self.path.name}\n'
                f'{self.size:,} байт / {self.blocks} XMODEM блоков ({self.padded_size:,} байт)\n'
                f'RAM: 0x{APP_ORIGIN:08X}, подтверждённый адрес входа 0x{APP_ENTRY:08X}\n'
                f'Заголовок [0:16]: {h}\n'
                f'SHA256: {self.sha256}')


def inspect_binary(path: Path, demo_path: Path) -> BinaryInfo:
    """Conservative guard based on the user's *board-tested* demo.bin.

    This does NOT prove that arbitrary RISC-V code is executable. It avoids
    sending a random image, ELF, FPGA .fs, or an image beyond the app RAM window.
    """
    path = path.expanduser().resolve()
    if not path.is_file():
        raise FileNotFoundError(path)
    if path.suffix.lower() != '.bin':
        raise ValueError('Нужен raw RV32I .bin, не .elf/.fs/.hex')
    size = path.stat().st_size
    if size < 20:
        raise ValueError('Файл слишком мал: нужен 16-байтный заголовок + код RV32I')
    padded = ((size + XMODEM_BLOCK_SIZE - 1) // XMODEM_BLOCK_SIZE) * XMODEM_BLOCK_SIZE
    if padded > APP_CAPACITY:
        raise ValueError(f'Превышено окно RAM приложения: {padded} > {APP_CAPACITY} байт (включая XMODEM padding)')
    if not demo_path.is_file():
        raise ValueError('Нет рабочего demo.bin для сравнения сигнатуры')
    demo_magic_bytes = demo_path.read_bytes()[:4]
    with path.open('rb') as f:
        header_bytes = f.read(16)
    if header_bytes[:4] != demo_magic_bytes:
        raise ValueError(f'Неверная сигнатура приложения: {header_bytes[:4].hex()} != {demo_magic_bytes.hex()} (demo.bin)')
    import struct
    values = struct.unpack('<IIII', header_bytes)
    reference = struct.unpack('<IIII', demo_path.read_bytes()[:16])
    if reference != (0x31444B50, 1292, APP_ENTRY, 0):
        raise ValueError('Эталон demo.bin имеет неожиданный ABI; передача запрещена')
    if values[1] != size:
        raise ValueError(f'LOAD BAD LENGTH: header[4:8]={values[1]}, actual file={size}. '
                         'Поле длины должно содержать точный размер файла без XMODEM padding.')
    if values[2] != APP_ENTRY:
        raise ValueError(f'BAD ENTRY: header[8:12]=0x{values[2]:08X}, '
                         f'ожидается 0x{APP_ENTRY:08X}')
    if values[3] != 0:
        raise ValueError('BAD RESERVED: header[12:16] должен быть нулём')
    return BinaryInfo(path, size, padded, padded // XMODEM_BLOCK_SIZE,
                      sha256_file(path), values, int.from_bytes(demo_magic_bytes, 'little'))


def command_for_host(paths: Paths, program: Path, *, port: str = 'COM10',
                     baud: int = 115200, python: str = sys.executable,
                     operation: str = 'app') -> list[str]:
    if operation not in ('app', 'monitor'):
        raise ValueError('unknown operation')
    cmd = [python, '-u', '-B', str(paths.host), '--port', port,
           '--baud', str(baud), '--monitor', str(paths.monitor),
           '--demo', str(program)]
    if operation == 'app':
        cmd += ['--attach', '--auto-demo']
    return cmd


@dataclass(frozen=True)
class TransferResult:
    rc: int
    out: str
    xmodem_ack: bool
    ran: bool
    returned: bool
    loader_pass: bool
    log: Optional[Path] = None
    timed_out: bool = False
    cancelled: bool = False

    @property
    def pass_app(self) -> bool:
        return self.rc == 0 and self.xmodem_ack and self.ran and self.returned and not self.timed_out


def parse_transfer_output(out: str, rc: int = 0, operation: str = 'app') -> TransferResult:
    # Original host_console.py may print UART command transcript and independent
    # summary lines. Be strict on RETURN, but do not require demo-specific CRC
    # for arbitrary user binaries.
    upper = out.upper()
    ack = ('XMODEM TRANSFER ACK / PASS' in upper or
           'XMODEM-CRC' in upper and re.search(r'\bACK\b', upper) is not None or
           bool(re.search(r'\b\d+/\d+\s+ACK\b', upper)))
    ran = re.search(r'(?m)^\s*RUN\s+(?:0X)?[0-9A-F]{8}\s*$', upper) is not None
    returned = 'RUN RETURNED TO PIKOSOL' in upper
    # The verified host emits an independent 'SERIAL TEST PASS' after its
    # demo-specific end-to-end check; this also implies successful reception.
    if returned and 'SERIAL TEST PASS' in upper:
        ack = True
    monitor = 'PIKOSOL MONITOR ACTIVE' in upper or ('PIKOSOL TP20' in upper and 'PIKOSOL>' in upper)
    result = TransferResult(rc=rc, out=out, xmodem_ack=ack, ran=ran,
                            returned=returned, loader_pass=monitor)
    return result


def default_log_folder() -> Path:
    return Path(tempfile.gettempdir()) / 'PiKoSoL_TP20_FileManager'


def save_transfer_log(operation: str, program: Path, result: TransferResult,
                      log_folder: Optional[Path] = None) -> Path:
    folder = log_folder or default_log_folder()
    folder.mkdir(parents=True, exist_ok=True)
    filename = (datetime.now().strftime('%Y%m%d_%H%M%S_%f') +
                f'_{re.sub("[^A-Za-z0-9_-]", "_", operation)}.log')
    file = folder / filename
    content = (f'PiKoSoL TP20 / PC-only File Manager\n'
               f'Operation: {operation}\nFile: {program}\n'
               f'Return code: {result.rc}\nXMODEM ACK: {result.xmodem_ack}\n'
               f'RUN reached: {result.ran}\nRUN returned: {result.returned}\n'
               f'Timeout: {result.timed_out}\nCancelled: {result.cancelled}\n'
               f'--- host_console.py ---\n{result.out}\n')
    file.write_text(content, encoding='utf-8', errors='replace')
    # Do not accumulate test artifacts indefinitely; never touch user sources.
    for old in sorted(folder.glob('*.log'), key=lambda p: p.stat().st_mtime, reverse=True)[12:]:
        try:
            old.unlink()
        except OSError:
            pass
    return file


def xmodem_source_info() -> str:
    return ('Транспорт XMODEM-CRC выполняется штатным host_console.py; '
            'GUI не перепрограммирует FPGA. Передача .bin производится в RAM. ')


def audit_headers(paths: Paths, generated: Path) -> int:
    """Pure read-only audit: no serial, no FPGA and no writes."""
    import struct
    try:
        check_baseline(paths)
    except Exception as ex:
        print('AUDIT_REFUSED:', ex)
        return 2
    files = [paths.demo]
    if generated.is_dir():
        files.extend(sorted(f for f in generated.glob('*.bin') if f.is_file()))
    print('=== PIKOSOL TP20 BIN HEADER AUDIT / NO COM / NO WRITES ===')
    print('BASELINE:', paths.root)
    for f in files:
        raw = f.read_bytes()
        if len(raw) < 16:
            print(f.name, 'TOO SHORT')
            continue
        w = struct.unpack_from('<IIII', raw, 0)
        print('FILE:', f.name)
        print('  PATH:', f)
        print('  BYTES:', len(raw), 'PADDED:', ((len(raw)+127)//128)*128)
        print('  HEADER_HEX:', raw[:16].hex(' '))
        print('  HEADER_U32:', ' '.join(f'0x{x:08X}' for x in w))
        print('  HEADER_DEC:', ' '.join(str(x) for x in w))
        print('  SHA256:', hashlib.sha256(raw).hexdigest())
    print('AUDIT COMPLETE; NO COM / NO FPGA CHANGES')
    return 0

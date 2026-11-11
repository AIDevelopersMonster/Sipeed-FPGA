#!/usr/bin/env python3
"""Read-only FAT32 file browser over the qualified SD-05 CMD17 UART bridge.

The FPGA stays unchanged. All FAT32 parsing is on the host. Supports an MBR
FAT32 partition, UTF-16 LFN with 8.3 fallback, subdirectories, FAT chains,
bounded reads, CRC-framed single-sector transport. No SD write commands.
Python 3.9+, pyserial required only for real COM operation.
"""
import argparse
from collections import OrderedDict
from dataclasses import dataclass
import hashlib
from pathlib import Path
import sys
import time

from protocol import ProtocolError, parse_reply, request


class FAT32Error(ValueError):
    pass


def le16(buf, offset):
    return int.from_bytes(buf[offset:offset + 2], "little")


def le32(buf, offset):
    return int.from_bytes(buf[offset:offset + 4], "little")


def short_checksum(name11):
    checksum = 0
    for byte in name11:
        checksum = (((checksum & 1) << 7) + (checksum >> 1) + byte) & 255
    return checksum


def short_name(record):
    value = bytearray(record[:11])
    if value[0] == 0x05:
        value[0] = 0xE5
    stem = bytes(value[:8]).decode("cp437").rstrip(" ")
    ext = bytes(value[8:11]).decode("cp437").rstrip(" ")
    return stem + ("." + ext if ext else "")


def lfn_name(records, short11):
    """LFN entries are stored last chunk first, then sequence 1."""
    if not records:
        return None
    count = records[0][0] & 0x1F
    if count == 0 or count != len(records) or not (records[0][0] & 0x40):
        return None
    checksum = short_checksum(short11)
    for index, entry in enumerate(records):
        if (entry[0] & 0x1F) != count - index:
            return None
        if index and entry[0] & 0x40:
            return None
        if entry[11] != 0x0F or entry[12] or entry[13] != checksum:
            return None
        if entry[26:28] != b"\x00\x00":
            return None
    raw = b"".join(
        entry[1:11] + entry[14:26] + entry[28:32]
        for entry in reversed(records)
    )
    try:
        name = raw.decode("utf-16le").split("\x00", 1)[0].rstrip("\uffff")
    except UnicodeError:
        return None
    if not name or "/" in name or "\\" in name:
        return None
    return name


@dataclass(frozen=True)
class DirEntry:
    name: str
    alias: str
    attr: int
    cluster: int
    size: int

    @property
    def is_dir(self):
        return bool(self.attr & 0x10)


class SectorPort:
    """One persistent COM session; every request validates seq/LBA/CRC16."""

    def __init__(self, port, *, timeout=10.0):
        if timeout <= 0:
            raise FAT32Error("timeout must be positive")
        self.port_name = port
        self.timeout = timeout
        self.seq = 0
        self.ser = None

    def __enter__(self):
        import serial
        self.ser = serial.Serial(
            self.port_name, baudrate=115200, bytesize=8, parity="N",
            stopbits=1, timeout=0.1, write_timeout=2,
            xonxoff=False, rtscts=False, dsrdtr=False
        )
        self.ser.reset_input_buffer()
        return self

    def __exit__(self, _type, _value, _trace):
        if self.ser is not None:
            self.ser.close()

    def _read_exact(self, size, deadline):
        data = bytearray()
        while len(data) < size and time.monotonic() < deadline:
            data.extend(self.ser.read(size - len(data)))
        if len(data) != size:
            raise TimeoutError(f"UART incomplete reply: {len(data)}/{size} bytes")
        return bytes(data)

    def read_sector(self, lba):
        if not 0 <= lba <= 0xFFFFFFFF:
            raise FAT32Error("requested LBA outside 32-bit SDHC range")
        if self.ser is None:
            raise FAT32Error("COM port is not open")
        self.seq = (self.seq + 1) & 255
        command = request(lba, self.seq)
        if self.ser.write(command) != len(command):
            raise FAT32Error("partial UART request write")
        self.ser.flush()
        deadline = time.monotonic() + self.timeout
        header = self._read_exact(2, deadline)
        if header == b"ZD":
            frame = header + self._read_exact(521, deadline)
        elif header == b"ZE":
            frame = header + self._read_exact(8, deadline)
        else:
            raise FAT32Error(f"unexpected UART header {header.hex()}")
        sector = parse_reply(frame, seq=self.seq, lba=lba).data
        if len(sector) != 512:
            raise FAT32Error("invalid sector length from protocol")
        return sector


class FAT32Volume:
    """Filesystem parser built over a read_sector(lba) callback."""

    def __init__(self, read_sector, *, max_sectors=4096, max_dir_sectors=128):
        if max_sectors < 2 or max_dir_sectors < 1:
            raise FAT32Error("invalid read limits")
        self.reader = read_sector
        self.max_sectors = max_sectors
        self.max_dir_sectors = max_dir_sectors
        self.read_count = 0
        self.cache = OrderedDict()
        mbr = self.read(0)
        if mbr[510:512] != b"\x55\xAA":
            raise FAT32Error("MBR signature is not 55AA")
        partitions = []
        for index in range(4):
            start = 446 + index * 16
            kind = mbr[start + 4]
            lba = le32(mbr, start + 8)
            sectors = le32(mbr, start + 12)
            if kind in (0x0B, 0x0C) and lba and sectors:
                partitions.append((kind, lba, sectors))
        if len(partitions) != 1:
            raise FAT32Error("expected exactly one MBR FAT32 partition")
        self.partition_type, self.partition_lba, self.partition_sectors = partitions[0]
        vbr = self.read(self.partition_lba)
        if vbr[510:512] != b"\x55\xAA":
            raise FAT32Error("VBR signature is not 55AA")
        self.bps = le16(vbr, 11)
        self.spc = vbr[13]
        self.reserved = le16(vbr, 14)
        self.fats = vbr[16]
        self.fatsz = le32(vbr, 36)
        self.rootclus = le32(vbr, 44)
        self.total = le32(vbr, 32)
        flags = le16(vbr, 40)
        active = flags & 0x0F if flags & 0x80 else 0
        if self.bps != 512 or self.spc not in (1, 2, 4, 8, 16, 32, 64, 128):
            raise FAT32Error("unsupported sector or cluster size")
        if not self.reserved or self.fats not in (1, 2) or not self.fatsz:
            raise FAT32Error("invalid FAT32 reserved/FAT geometry")
        if le16(vbr, 17) or le16(vbr, 22) or le16(vbr, 42):
            raise FAT32Error("invalid FAT32 root entries, FAT16 size or FS version")
        if active >= self.fats:
            raise FAT32Error("invalid active FAT index")
        if not self.total or self.total > self.partition_sectors:
            raise FAT32Error("BPB total sectors exceed partition")
        self.fat_lba = self.partition_lba + self.reserved + active * self.fatsz
        self.data_lba = self.partition_lba + self.reserved + self.fats * self.fatsz
        data_sectors = self.total - self.reserved - self.fats * self.fatsz
        if data_sectors <= 0:
            raise FAT32Error("no FAT32 data area")
        self.clusters = data_sectors // self.spc
        if self.clusters < 65525 or self.clusters > 0x0FFFFFF5:
            raise FAT32Error("invalid FAT32 cluster count")
        if (self.clusters + 2) * 4 > self.fatsz * 512:
            raise FAT32Error("FAT smaller than required cluster table")
        self._valid_cluster(self.rootclus)
        self.root_lba = self.cluster_lba(self.rootclus)

    def read(self, lba):
        if lba in self.cache:
            self.cache.move_to_end(lba)
            return self.cache[lba]
        if not 0 <= lba <= 0xFFFFFFFF or self.read_count >= self.max_sectors:
            raise FAT32Error("sector address or read-budget limit reached")
        data = self.reader(lba)
        if len(data) != 512:
            raise FAT32Error(f"LBA {lba}: invalid sector size {len(data)}")
        self.read_count += 1
        self.cache[lba] = bytes(data)
        if len(self.cache) > 64:
            self.cache.popitem(last=False)
        return self.cache[lba]

    def _valid_cluster(self, cluster):
        if not 2 <= cluster < self.clusters + 2:
            raise FAT32Error(f"cluster {cluster} outside data area")

    def cluster_lba(self, cluster):
        self._valid_cluster(cluster)
        return self.data_lba + (cluster - 2) * self.spc

    def fat_next(self, cluster):
        self._valid_cluster(cluster)
        offset = cluster * 4
        lba = self.fat_lba + offset // 512
        if lba >= self.fat_lba + self.fatsz:
            raise FAT32Error("cluster FAT entry out of bounds")
        value = le32(self.read(lba), offset % 512) & 0x0FFFFFFF
        if value >= 0x0FFFFFF8:
            return None
        self._valid_cluster(value)
        return value

    def chain(self, cluster, *, max_clusters):
        seen = set()
        while True:
            self._valid_cluster(cluster)
            if cluster in seen:
                raise FAT32Error(f"FAT cluster loop at {cluster}")
            if len(seen) >= max_clusters:
                raise FAT32Error("FAT cluster traversal limit exceeded")
            seen.add(cluster)
            yield cluster
            cluster = self.fat_next(cluster)
            if cluster is None:
                return

    def listdir(self, cluster=None):
        cluster = self.rootclus if cluster is None else cluster
        pending = []
        dirs = []
        scanned = 0
        for current in self.chain(cluster, max_clusters=self.max_dir_sectors):
            start = self.cluster_lba(current)
            for sector_index in range(self.spc):
                if scanned >= self.max_dir_sectors:
                    raise FAT32Error("directory-sector safety limit exceeded")
                sector = self.read(start + sector_index)
                scanned += 1
                for slot in range(16):
                    entry = sector[slot * 32:(slot + 1) * 32]
                    if entry[0] == 0:
                        return dirs
                    if entry[0] == 0xE5:
                        pending = []
                        continue
                    attr = entry[11]
                    if attr == 0x0F:
                        pending.append(entry)
                        continue
                    name = short_name(entry)
                    long_name = lfn_name(pending, entry[:11])
                    pending = []
                    if attr & 0x08 or attr & 0xC0 or name in (".", ".."):
                        continue
                    cluster_num = (le16(entry, 20) << 16) | le16(entry, 26)
                    dirs.append(DirEntry(
                        long_name or name, name, attr,
                        cluster_num, le32(entry, 28)
                    ))
        return dirs

    def resolve(self, path):
        parts = [s for s in path.replace("\\", "/").split("/") if s]
        if any(p in (".", "..") for p in parts):
            raise FAT32Error("relative components . and .. not supported")
        current = None
        directory = self.rootclus
        for index, part in enumerate(parts):
            matches = [e for e in self.listdir(directory)
                       if e.name.casefold() == part.casefold()
                       or e.alias.casefold() == part.casefold()]
            if len(matches) != 1:
                raise FAT32Error(f"entry not found or ambiguous: {part}")
            current = matches[0]
            if index + 1 < len(parts):
                if not current.is_dir:
                    raise FAT32Error(f"not a directory: {part}")
                directory = current.cluster
        return current

    def list_path(self, path):
        target = self.resolve(path)
        if target is None:
            return self.listdir()
        if not target.is_dir:
            raise FAT32Error("ls target is not a directory")
        return self.listdir(target.cluster)

    def file_bytes(self, path, *, max_file_bytes=2 * 1024 * 1024):
        target = self.resolve(path)
        if target is None or target.is_dir:
            raise FAT32Error("path must refer to a regular file")
        if target.size > max_file_bytes:
            raise FAT32Error(
                f"file size {target.size} exceeds {max_file_bytes}-byte safety limit"
            )
        if target.size == 0:
            return b""
        remaining = target.size
        result = bytearray()
        cluster_bytes = self.spc * 512
        needed = (target.size + cluster_bytes - 1) // cluster_bytes
        for cluster in self.chain(target.cluster, max_clusters=needed):
            lba = self.cluster_lba(cluster)
            for n in range(self.spc):
                if remaining == 0:
                    break
                count = min(512, remaining)
                result.extend(self.read(lba + n)[:count])
                remaining -= count
            if remaining == 0:
                break
        if remaining:
            raise FAT32Error(f"truncated FAT chain, missing {remaining} bytes")
        return bytes(result)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--port", required=True, help="SD-05 UART COM port, e.g. COM10")
    ap.add_argument("--timeout", type=float, default=10.0)
    ap.add_argument("--max-sectors", type=int, default=4096)
    cmds = ap.add_subparsers(dest="command", required=True)
    cmds.add_parser("info", help="print FAT32 volume geometry")
    ls = cmds.add_parser("ls", help="list directory; no files are copied")
    ls.add_argument("path", nargs="?", default="/")
    get = cmds.add_parser("get", help="copy one file to PC (never to SD)")
    get.add_argument("path")
    get.add_argument("output", type=Path)
    get.add_argument("--max-file-bytes", type=int, default=2 * 1024 * 1024)
    args = ap.parse_args()
    if args.max_sectors < 2:
        ap.error("--max-sectors must be >= 2")
    try:
        with SectorPort(args.port, timeout=args.timeout) as transport:
            disk = FAT32Volume(transport.read_sector, max_sectors=args.max_sectors)
            print(f"SD051_VOLUME_PASS: VOL={disk.partition_lba} FAT={disk.fat_lba} "
                  f"DATA={disk.data_lba} ROOT={disk.root_lba} "
                  f"SPC={disk.spc} CLUS={disk.clusters}")
            if args.command == "ls":
                entries = disk.list_path(args.path)
                for entry in entries:
                    kind = "DIR " if entry.is_dir else "FILE"
                    print(f"{kind} {entry.size:>10} CLUS={entry.cluster:08X} "
                          f"ATTR={entry.attr:02X} {entry.name}")
                print(f"SD051_LS_PASS: PATH={args.path!r} ENTRIES={len(entries)} "
                      f"SECTORS_READ={disk.read_count}")
            elif args.command == "get":
                if args.max_file_bytes < 0:
                    raise FAT32Error("--max-file-bytes must be nonnegative")
                data = disk.file_bytes(args.path,
                                       max_file_bytes=args.max_file_bytes)
                with args.output.open("xb") as dest:
                    dest.write(data)
                print(f"SD051_FILE_PASS: BYTES={len(data)} "
                      f"SHA256={hashlib.sha256(data).hexdigest().upper()} "
                      f"SECTORS_READ={disk.read_count}")
                print(f"SD051_PC_FILE: {args.output}")
        return 0
    except (OSError, FAT32Error, ProtocolError, TimeoutError, ImportError) as exc:
        print(f"SD051_FAIL: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

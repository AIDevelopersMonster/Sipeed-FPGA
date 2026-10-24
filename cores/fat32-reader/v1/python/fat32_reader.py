"""Read-only FAT32 interpreter over an abstract 512-byte LBA block device.

Dependency contract: read_sector(lba: int) -> bytes of length 512.
This module never opens serial ports, accesses hardware or writes to a device.
"""
from __future__ import annotations

from collections import OrderedDict
from dataclasses import dataclass
from struct import unpack_from
from typing import Callable, Iterator


class FATError(ValueError):
    """Malformed, unsafe, or unsupported FAT32 volume or path."""


@dataclass(frozen=True)
class Partition:
    number: int
    type_code: int
    first_lba: int
    sectors: int


@dataclass(frozen=True)
class DirEntry:
    name: str
    short_name: str
    attr: int
    first_cluster: int
    size: int

    @property
    def is_dir(self) -> bool:
        return bool(self.attr & 0x10)

    @property
    def is_file(self) -> bool:
        return not self.is_dir


def lfn_checksum(short_name: bytes) -> int:
    if len(short_name) != 11:
        raise ValueError("FAT short-name checksum requires exactly 11 bytes")
    crc = 0
    for value in short_name:
        crc = (((crc & 1) << 7) | (crc >> 1))
        crc = (crc + value) & 0xFF
    return crc


def _lfn_fragment(record: bytes) -> bytes:
    return record[1:11] + record[14:26] + record[28:32]


def _short_name(record: bytes) -> str:
    stem = bytearray(record[:8])
    if stem[0] == 0x05:
        stem[0] = 0xE5
    base = stem.decode("cp437").rstrip(" ")
    ext = record[8:11].decode("cp437").rstrip(" ")
    flags = record[12]
    if flags & 0x08:
        base = base.lower()
    if flags & 0x10:
        ext = ext.lower()
    return base + ("." + ext if ext else "")


def _lfn_name(entries: list[tuple[int, int, bytes]], short_name: bytes) -> str | None:
    """Return long name only for a complete, checksummed descending VFAT chain."""
    if not entries:
        return None
    count = entries[0][0] & 0x1F
    if not 1 <= count <= 20 or entries[0][0] != (0x40 | count):
        return None
    if len(entries) != count:
        return None
    correct = lfn_checksum(short_name)
    for index, (order, checksum, _) in enumerate(entries):
        expected = (0x40 | count) if index == 0 else count - index
        if order != expected or checksum != correct:
            return None
    joined = b"".join(fragment for _, _, fragment in reversed(entries))
    chars = bytearray()
    for offset in range(0, len(joined), 2):
        unit = joined[offset:offset + 2]
        if unit in (b"\x00\x00", b"\xff\xff"):
            break
        chars.extend(unit)
    return chars.decode("utf-16le", "replace") if chars else None


class FAT32:
    """Bounded FAT32-only block reader: no write interface or filesystem mutation."""

    FAT32_PARTITION_TYPES = frozenset((0x0B, 0x0C, 0x1B, 0x1C))
    SECTOR_SIZE = 512

    def __init__(
        self,
        read_sector: Callable[[int], bytes],
        *,
        max_sector_reads: int = 256,
        max_chain_clusters: int = 128,
        max_directory_entries: int = 2048,
    ):
        if min(max_sector_reads, max_chain_clusters, max_directory_entries) < 1:
            raise ValueError("FAT32 safety limits must be positive")
        self._backend = read_sector
        self.max_sector_reads = max_sector_reads
        self.max_chain_clusters = max_chain_clusters
        self.max_directory_entries = max_directory_entries
        self.sectors_read = 0
        self._cache: OrderedDict[int, bytes] = OrderedDict()

        mbr = self._read(0)
        if mbr[510:512] != b"\x55\xaa":
            raise FATError("MBR signature 55 AA absent")
        choices = []
        for index in range(4):
            offset = 446 + 16 * index
            kind = mbr[offset + 4]
            first, sectors = unpack_from("<II", mbr, offset + 8)
            if kind in self.FAT32_PARTITION_TYPES and first and sectors:
                if first + sectors > 1 << 32:
                    raise FATError("partition address range exceeds 32-bit LBA")
                choices.append(Partition(index + 1, kind, first, sectors))
        if not choices:
            raise FATError("no MBR FAT32 partition 0B/0C/1B/1C; GPT/exFAT not supported")
        self.partition = choices[0]
        vbr = self._read(self.partition.first_lba)
        if vbr[510:512] != b"\x55\xaa":
            raise FATError("FAT32 VBR signature 55 AA absent")
        self.bytes_per_sector = unpack_from("<H", vbr, 11)[0]
        self.sectors_per_cluster = vbr[13]
        self.reserved_sectors = unpack_from("<H", vbr, 14)[0]
        self.num_fats = vbr[16]
        root_entry_count = unpack_from("<H", vbr, 17)[0]
        total_sectors16 = unpack_from("<H", vbr, 19)[0]
        fat_sectors16 = unpack_from("<H", vbr, 22)[0]
        self.hidden_sectors = unpack_from("<I", vbr, 28)[0]
        self.total_sectors = unpack_from("<I", vbr, 32)[0]
        self.sectors_per_fat = unpack_from("<I", vbr, 36)[0]
        ext_flags = unpack_from("<H", vbr, 40)[0]
        filesystem_version = unpack_from("<H", vbr, 42)[0]
        self.root_cluster = unpack_from("<I", vbr, 44)[0]

        if self.bytes_per_sector != 512:
            raise FATError("HOST-01 requires a 512-byte logical FAT32 sector")
        if (self.sectors_per_cluster not in (1, 2, 4, 8, 16, 32, 64, 128)
                or self.reserved_sectors < 1
                or self.num_fats not in (1, 2)
                or self.sectors_per_fat < 1
                or root_entry_count != 0
                or total_sectors16 != 0
                or fat_sectors16 != 0
                or filesystem_version != 0):
            raise FATError("unsupported or inconsistent FAT32 BPB")
        if (self.total_sectors > self.partition.sectors
                or self.hidden_sectors != self.partition.first_lba):
            raise FATError("MBR partition bounds and BPB do not match")
        self.metadata_sectors = self.reserved_sectors + self.num_fats * self.sectors_per_fat
        if self.metadata_sectors >= self.total_sectors:
            raise FATError("FAT32 metadata exceeds total sectors")
        self.cluster_count = ((self.total_sectors - self.metadata_sectors)
                              // self.sectors_per_cluster)
        if not 65525 <= self.cluster_count < 0x0FFFFFF5:
            raise FATError("FAT32 cluster count is invalid (possibly FAT12/16)")
        if (self.cluster_count + 2) * 4 > self.sectors_per_fat * 512:
            raise FATError("FAT table cannot index the data cluster count")
        self.fat_index = (ext_flags & 0x0F) if (ext_flags & 0x80) else 0
        if self.fat_index >= self.num_fats:
            raise FATError("BPB active FAT index is invalid")
        self.first_fat_lba = (self.partition.first_lba + self.reserved_sectors
                              + self.fat_index * self.sectors_per_fat)
        self.first_data_lba = self.partition.first_lba + self.metadata_sectors
        self._check_cluster(self.root_cluster)

    def _read(self, lba: int) -> bytes:
        if not 0 <= lba <= 0xFFFFFFFF:
            raise FATError(f"out-of-range LBA: {lba}")
        if lba in self._cache:
            self._cache.move_to_end(lba)
            return self._cache[lba]
        if self.sectors_read >= self.max_sector_reads:
            raise FATError(f"sector-read safety limit: {self.max_sector_reads}")
        value = self._backend(lba)
        if not isinstance(value, (bytes, bytearray)) or len(value) != 512:
            raise FATError(f"wrong sector size for LBA {lba}")
        result = bytes(value)
        self._cache[lba] = result
        if len(self._cache) > 64:
            self._cache.popitem(last=False)
        self.sectors_read += 1
        return result

    def _check_cluster(self, cluster: int) -> None:
        if not 2 <= cluster < self.cluster_count + 2:
            raise FATError(f"cluster out of FAT32 data range: 0x{cluster:08X}")

    def cluster_lba(self, cluster: int) -> int:
        self._check_cluster(cluster)
        return self.first_data_lba + (cluster - 2) * self.sectors_per_cluster

    def next_cluster(self, cluster: int) -> int | None:
        self._check_cluster(cluster)
        offset = cluster * 4
        lba = self.first_fat_lba + offset // 512
        value = unpack_from("<I", self._read(lba), offset % 512)[0] & 0x0FFFFFFF
        if value >= 0x0FFFFFF8:
            return None
        if value == 0x0FFFFFF7:
            raise FATError(f"bad FAT32 cluster marker after cluster {cluster}")
        self._check_cluster(value)
        return value

    def cluster_chain(self, first_cluster: int) -> Iterator[int]:
        self._check_cluster(first_cluster)
        seen: set[int] = set()
        cluster = first_cluster
        while True:
            if len(seen) >= self.max_chain_clusters:
                raise FATError("FAT cluster chain exceeds configured limit")
            if cluster in seen:
                raise FATError(f"cycle in FAT cluster chain at {cluster}")
            seen.add(cluster)
            yield cluster
            cluster = self.next_cluster(cluster)
            if cluster is None:
                return

    def listdir(self, start_cluster: int | None = None) -> list[DirEntry]:
        cluster = self.root_cluster if start_cluster is None else start_cluster
        entries: list[DirEntry] = []
        lfn: list[tuple[int, int, bytes]] = []
        for current in self.cluster_chain(cluster):
            lba0 = self.cluster_lba(current)
            for sec_index in range(self.sectors_per_cluster):
                sector = self._read(lba0 + sec_index)
                for offset in range(0, 512, 32):
                    item = sector[offset:offset + 32]
                    if item[0] == 0:
                        return entries
                    if item[0] == 0xE5:
                        lfn.clear()
                        continue
                    if item[11] == 0x0F:
                        order = item[0]
                        if (order & 0x40) and 1 <= (order & 0x1F) <= 20:
                            lfn = [(order, item[13], _lfn_fragment(item))]
                        elif lfn and order == ((lfn[-1][0] & 0x1F) - 1):
                            lfn.append((order, item[13], _lfn_fragment(item)))
                        else:
                            lfn.clear()
                        continue
                    if item[11] & 0x08:
                        lfn.clear()  # volume-label entry, not a file
                        continue
                    short = _short_name(item)
                    long = _lfn_name(lfn, item[:11])
                    lfn.clear()
                    first = ((unpack_from("<H", item, 20)[0] << 16)
                             | unpack_from("<H", item, 26)[0])
                    size = unpack_from("<I", item, 28)[0]
                    if short not in (".", ".."):
                        entries.append(DirEntry(long or short, short, item[11], first, size))
                        if len(entries) > self.max_directory_entries:
                            raise FATError("directory entry count exceeds safety limit")
        return entries

    def locate(self, path: str) -> DirEntry | None:
        chunks = [x for x in path.replace("\\", "/").split("/") if x and x != "."]
        if any(x == ".." for x in chunks):
            raise FATError("parent-directory traversal not supported")
        if not chunks:
            return None
        folder = self.root_cluster
        match = None
        for index, chunk in enumerate(chunks):
            match = next((e for e in self.listdir(folder)
                          if chunk.casefold() in
                          (e.name.casefold(), e.short_name.casefold())), None)
            if match is None:
                raise FATError(f"path component not found: {chunk}")
            if index < len(chunks) - 1:
                if not match.is_dir:
                    raise FATError(f"not a directory: {chunk}")
                folder = match.first_cluster
        return match

    def list_path(self, path: str = "/") -> list[DirEntry]:
        found = self.locate(path)
        if found is None:
            return self.listdir()
        if not found.is_dir:
            raise FATError(f"not a directory: {path}")
        return self.listdir(found.first_cluster)

    def read_file(self, path: str, *, max_bytes: int = 64 * 1024) -> bytes:
        if max_bytes < 0:
            raise ValueError("max_bytes must not be negative")
        found = self.locate(path)
        if found is None or found.is_dir:
            raise FATError("not a regular file: " + path)
        if found.size > max_bytes:
            raise FATError(f"file size {found.size} exceeds max_bytes {max_bytes}")
        if found.size == 0:
            return b""
        if found.first_cluster < 2:
            raise FATError("nonempty file has no starting cluster")
        content = bytearray()
        remain = found.size
        for cluster in self.cluster_chain(found.first_cluster):
            lba = self.cluster_lba(cluster)
            for index in range(self.sectors_per_cluster):
                if remain == 0:
                    return bytes(content)
                payload = self._read(lba + index)
                take = min(512, remain)
                content.extend(payload[:take])
                remain -= take
            if remain == 0:
                return bytes(content)
        raise FATError(f"FAT chain ended with {remain} bytes still missing")

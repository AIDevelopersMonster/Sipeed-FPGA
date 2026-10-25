#!/usr/bin/env python3
"""SDRWTEST.BIN: qualified 512-byte FAT32 file-sector CMD24 experiment.

make: create one 512-byte test file on PC (copy to a DISPOSABLE card via reader).
inspect: with card in FPGA, locate actual file LBA, save preimage + manifest.
validate: inspect offline manifest and immutable original backup (no COM).
preflight: with card in FPGA, re-check exact FAT32 file and sector (NO WRITE).
write: ONE CMD24, verified with CMD17, NEVER automatic retry.

Requires SD-05/SD-06 UART read bridge and pyserial on hardware commands.
Do not use on cards with valuable data. The FPGA must run a separately
qualified firmware with write permission compiled for exactly this file LBA.
"""
import argparse
import hashlib
import json
from pathlib import Path
import secrets
import sys

HERE = Path(__file__).resolve()
sys.path.insert(0, str(HERE.parents[2] / "sd05-lba-bridge" / "tools"))
from fat32_host import FAT32Volume, FAT32Error
from sd_rw import Transport

FILE_NAME = "SDRWTEST.BIN"
MAGIC = b"SDRWTEST-FPGA-CMD24-V1|"
VERSION = "SD_RW_SCRATCH_V1"
CONFIRM = "WRITE-ONE-DISPOSABLE-SD-SCRATCH-SECTOR"

def sha(data):
    return hashlib.sha256(data).hexdigest().upper()

def new_image(old):
    """Change user data while retaining the scratch identity prefix."""
    if len(old) != 512 or not old.startswith(MAGIC):
        raise ValueError("scratch preimage is invalid")
    return old[:64] + bytes(x ^ 0x5A for x in old[64:])

def make_file(target):
    target = Path(target)
    nonce = secrets.token_bytes(16)
    data = bytearray(MAGIC + nonce)
    while len(data) < 512:
        data.extend(hashlib.sha256(nonce + len(data).to_bytes(4, "little")).digest())
    with target.open("xb") as out:
        out.write(bytes(data[:512]))
    print(f"SCRATCH_FILE_CREATED: {target.resolve()}")
    print(f"SCRATCH_FILE_SHA256: {sha(bytes(data[:512]))}")
    print("Copy this 512-byte file into the root of a DISPOSABLE FAT32 SDHC card")
    print("under the name SDRWTEST.BIN. Safely eject the card; insert into FPGA.")
    return 0

def find_scratch(reader):
    disk = FAT32Volume(reader, max_sectors=128, max_dir_sectors=64)
    entry = disk.resolve("/" + FILE_NAME)
    if entry is None or entry.is_dir or entry.size != 512:
        raise ValueError("SDRWTEST.BIN must be an allocated regular 512-byte file")
    if (entry.attr & (0x01 | 0x02 | 0x04 | 0x08)) != 0:
        raise ValueError("scratch file is read-only/hidden/system/volume")
    if disk.fat_next(entry.cluster) is not None:
        raise ValueError("scratch file is not a single-cluster file")
    lba = disk.cluster_lba(entry.cluster)
    if lba < disk.data_lba or lba >= disk.partition_lba + disk.total:
        raise ValueError("scratch sector is outside FAT32 data area")
    original = disk.read(lba)
    if not original.startswith(MAGIC):
        raise ValueError("scratch file sector marker not found")
    mbr_hash = sha(disk.read(0))
    vbr_hash = sha(disk.read(disk.partition_lba))
    return disk, entry, lba, original, mbr_hash, vbr_hash

def create_manifest(port, outdir):
    outdir = Path(outdir)
    if outdir.exists():
        raise ValueError(f"output directory exists; refusing overwrite: {outdir}")
    t = Transport(port, timeout=15)
    try:
        disk, entry, lba, original, mbr_hash, vbr_hash = find_scratch(t.read)
    finally:
        t.close()
    if lba == 0 or lba > 0xFFFFFFFE:
        raise ValueError("invalid physical scratch LBA")
    replacement = new_image(original)
    doc = {
        "format": VERSION,
        "file_name": FILE_NAME,
        "scratch_lba": lba,
        "file_cluster": entry.cluster,
        "file_size": 512,
        "partition_lba": disk.partition_lba,
        "partition_sectors": disk.partition_sectors,
        "fat32_total": disk.total,
        "data_lba": disk.data_lba,
        "sectors_per_cluster": disk.spc,
        "mbr_sha256": mbr_hash,
        "vbr_sha256": vbr_hash,
        "preimage_sha256": sha(original),
        "newimage_sha256": sha(replacement),
        "write_protocol": "UART-CAS-CMD17-CMD24-CMD17",
        "qualifier": "ONLY SCRATCH FILE ON DISPOSABLE CARD",
    }
    outdir.mkdir(parents=True)
    (outdir / "preimage.bin").write_bytes(original)
    (outdir / "newimage.bin").write_bytes(replacement)
    (outdir / "manifest.json").write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
    print(f"SD_RW_SCRATCH_INSPECT_PASS: LBA={lba} CLUSTER={entry.cluster}")
    print(f"SD_RW_SCRATCH_BACKUP_SHA256: {sha(original)}")
    print(f"SD_RW_SCRATCH_MANIFEST: {(outdir / 'manifest.json').resolve()}")
    print("NO WRITE OCCURRED. Review this sector identity before enabling CMD24.")
    return 0

def load_manifest(manifest, backup):
    doc = json.loads(Path(manifest).read_text(encoding="utf-8"))
    required = {
        "format", "file_name", "scratch_lba", "file_cluster", "file_size",
        "partition_lba", "partition_sectors", "fat32_total", "data_lba",
        "sectors_per_cluster", "mbr_sha256", "vbr_sha256", "preimage_sha256",
        "newimage_sha256", "write_protocol"
    }
    if not required.issubset(doc):
        raise ValueError("manifest missing required fields")
    old = Path(backup).read_bytes()
    lba = doc["scratch_lba"]
    if (doc["format"] != VERSION or doc["file_name"] != FILE_NAME
        or doc["file_size"] != 512 or type(lba) is not int
        or not (0 < lba < 0xFFFFFFFF)
        or type(doc["file_cluster"]) is not int
        or doc["file_cluster"] < 2
        or type(doc["data_lba"]) is not int
        or lba < doc["data_lba"]
        or lba >= doc["partition_lba"] + doc["fat32_total"]
        or doc["write_protocol"] != "UART-CAS-CMD17-CMD24-CMD17"
        or len(old) != 512 or not old.startswith(MAGIC)
        or sha(old) != doc["preimage_sha256"]
        or sha(new_image(old)) != doc["newimage_sha256"]):
        raise ValueError("invalid scratch manifest or original backup")
    print(f"SD_RW_SCRATCH_MANIFEST_PASS: LBA={lba} SHA256={sha(old)}")
    return doc, old, new_image(old)

def validate_card(transport, doc, old):
    disk, entry, lba, actual, mbr, vbr = find_scratch(transport.read)
    checks = {
        "scratch_lba": lba,
        "file_cluster": entry.cluster,
        "file_size": entry.size,
        "partition_lba": disk.partition_lba,
        "partition_sectors": disk.partition_sectors,
        "fat32_total": disk.total,
        "data_lba": disk.data_lba,
        "sectors_per_cluster": disk.spc,
        "mbr_sha256": mbr,
        "vbr_sha256": vbr,
    }
    for key, value in checks.items():
        if doc[key] != value:
            raise ValueError(f"CARD CHANGED: {key}: expected {doc[key]}, actual {value}")
    if actual != old:
        raise ValueError("SCRATCH SECTOR CHANGED; physical WRITE blocked")
    return lba

def run():
    p = argparse.ArgumentParser(description=__doc__)
    commands = p.add_subparsers(dest="command", required=True)
    make = commands.add_parser("make", help="create a 512-byte scratch file on PC")
    make.add_argument("--out", type=Path, required=True)
    inspect = commands.add_parser("inspect", help="locate scratch LBA via FPGA, no writes")
    inspect.add_argument("--port", default="COM10")
    inspect.add_argument("--out-dir", type=Path, required=True)
    validate = commands.add_parser("validate", help="validate manifest/backup without COM")
    validate.add_argument("--manifest", type=Path, required=True)
    validate.add_argument("--backup", type=Path, required=True)
    for name in ("preflight", "write"):
        cmd = commands.add_parser(name)
        cmd.add_argument("--port", default="COM10")
        cmd.add_argument("--manifest", type=Path, required=True)
        cmd.add_argument("--backup", type=Path, required=True)
        if name == "write":
            cmd.add_argument("--confirm", required=True)
    args = p.parse_args()
    if args.command == "make":
        return make_file(args.out)
    if args.command == "inspect":
        return create_manifest(args.port, args.out_dir)
    doc, old, new = load_manifest(args.manifest, args.backup)
    if args.command == "validate":
        return 0
    t = Transport(args.port, timeout=15)
    try:
        lba = validate_card(t, doc, old)
        print(f"SD_RW_SCRATCH_PREFLIGHT_PASS: LBA={lba} ORIGINAL_SHA256={sha(old)}")
        if args.command == "preflight":
            print("NO SD WRITES PERFORMED")
            return 0
        if args.confirm != CONFIRM:
            raise ValueError("WRITE confirmation string mismatch")
        if t.read(lba) != old:
            raise ValueError("preimage changed after preflight; refuse CMD24")
        # Never retry CMD24 automatically if acknowledgement is lost.
        print(f"SD_RW_CMD24_ATTEMPT: approved LBA={lba}", flush=True)
        try:
            t.write(lba, old, new)
        except Exception:
            print("CMD24 outcome uncertain; do NOT retry without new independent readback",
                  file=sys.stderr)
            raise
        readback = t.read(lba)
        if readback != new:
            raise ValueError("SD_RW_HW_WRITE_VERIFY_FAIL: CMD17 does not match")
        print(f"SD_RW_HW_WRITE_VERIFY_PASS: LBA={lba} BYTES=512 SHA256={sha(readback)}")
        print("No FAT32 metadata written. Original sector is preserved in preimage.bin.")
        return 0
    finally:
        t.close()

if __name__ == "__main__":
    try:
        raise SystemExit(run())
    except (ValueError, OSError, TimeoutError, FAT32Error, ImportError) as error:
        print(f"SD_RW_SCRATCH_FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)

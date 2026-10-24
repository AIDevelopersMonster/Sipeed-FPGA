#!/usr/bin/env python3
"""HOST-02: read-only FAT32 directories and file contents through HOST-01 UART."""
import argparse
import importlib.util
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
CORE = ROOT / "cores/fat32-reader/v1/python/fat32_reader.py"
HOST01 = ROOT / "experiments/host01-sector-read/tools/host01_sector.py"

def load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module

fat = load_module(CORE, "host02_fat32_core")
link = load_module(HOST01, "host01_sector_client")

def main(argv=None):
    p = argparse.ArgumentParser(description="HOST-02 FAT32 read-only browser over FPGA UART")
    p.add_argument("--port", default="COM10", help="HOST-01 serial port")
    p.add_argument("--timeout", type=float, default=20.0, help="seconds per sector")
    p.add_argument("--max-reads", type=int, default=256, help="max unique LBA reads in one command")
    cmds = p.add_subparsers(dest="command", required=True)
    cmds.add_parser("info", help="display FAT32 geometry without reading files")
    for command in ("ls", "cat", "extract"):
        sp = cmds.add_parser(command)
        sp.add_argument("path", nargs="?", default="/" if command=="ls" else None, help="FAT32 path")
        if command == "extract":
            sp.add_argument("--output", required=True, help="local destination file (never on SD)")
            sp.add_argument("--max-bytes", type=int, default=65536, help="explicit file size bound")
        if command == "cat":
            sp.add_argument("--max-bytes", type=int, default=4096, help="maximum data to print")
    args = p.parse_args(argv)
    if args.timeout <= 0 or args.max_reads < 2:
        p.error("timeout must be >0; max-reads must be >=2")
    if args.command in ("cat","extract") and not args.path:
        p.error("file path required")
    try:
        import serial
        with serial.Serial(port=args.port, baudrate=115200, timeout=args.timeout,
                           write_timeout=args.timeout) as ser:
            def block_read(lba):
                ser.reset_input_buffer()
                ser.write(link.request(lba))
                ser.flush()
                header = ser.read(7)
                if len(header) != 7 or header[:2] != b"\x5a\x81":
                    raise ValueError(f"HOST02_TRANSPORT_FAIL LBA={lba}: header {header.hex()}")
                tail = ser.read(514 if header[2] == 0 else 2)
                return link.parse_response(header+tail, lba)
            volume = fat.FAT32(block_read, max_sector_reads=args.max_reads)
            if args.command == "info":
                print(f"HOST02_FAT32_INFO_PASS PART={volume.partition.number} TYPE=0x{volume.partition.type_code:02X} START={volume.partition.first_lba}")
                print(f"SECTOR={volume.bytes_per_sector} CLUSTER_SECTORS={volume.sectors_per_cluster} CLUSTER_BYTES={volume.bytes_per_sector*volume.sectors_per_cluster}")
                print(f"FAT0_LBA={volume.first_fat_lba} DATA_LBA={volume.first_data_lba} ROOT_CLUSTER={volume.root_cluster} ROOT_LBA={volume.cluster_lba(volume.root_cluster)}")
                print(f"CLUSTERS={volume.cluster_count} SECTOR_READS={volume.sectors_read}")
            elif args.command == "ls":
                entries = volume.list_path(args.path)
                for entry in entries:
                    kind = "DIR " if entry.is_dir else "FILE"
                    print(f"{kind} CL={entry.first_cluster:08X} SIZE={entry.size:>10} NAME={entry.name}")
                print(f"HOST02_LIST_PASS PATH={args.path} ENTRIES={len(entries)} SECTOR_READS={volume.sectors_read}")
            else:
                if args.max_bytes <= 0:
                    p.error("max-bytes must be positive")
                payload = volume.read_file(args.path, max_bytes=args.max_bytes)
                if args.command == "cat":
                    sys.stdout.buffer.write(payload)
                    sys.stdout.buffer.flush()
                    print(f"\nHOST02_CAT_PASS BYTES={len(payload)} SECTOR_READS={volume.sectors_read}", file=sys.stderr)
                else:
                    out = pathlib.Path(args.output)
                    if out.exists():
                        raise fat.FATError("output already exists: refusing overwrite")
                    with open(out, "xb") as f:
                        f.write(payload)
                    print(f"HOST02_EXTRACT_PASS BYTES={len(payload)} OUTPUT={out} SECTOR_READS={volume.sectors_read}")
            return 0
    except (fat.FATError, ValueError, OSError, ImportError) as exc:
        print("HOST02_FAIL:", exc, file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())

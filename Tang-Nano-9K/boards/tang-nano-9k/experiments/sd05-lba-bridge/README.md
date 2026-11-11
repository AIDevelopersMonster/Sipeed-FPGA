# SD-05 — Python-controlled arbitrary LBA reader (host protocol seed)

**STATUS: exploratory RTL + Python reference, neither integrated UART transaction simulation nor Gowin STA nor physical qualification completed.**
UART RX and FPGA CMD17 bridge sources, independent CST, Python serial client and Gowin build scripts are present but have **not** passed hardware acceptance. Do NOT program the resulting bitstream without further qualification. No SD writes.

The frozen SD-04 bitstream still reads its first FAT32 root sector
autonomously. It cannot receive the SD-05 commands.

## Offline protocol tests

From the repository root:

```powershell
python -m unittest discover -s .\boards\tang-nano-9k\experiments\sd05-lba-bridge\tests -p "test_*.py" -v
```

The module `tools/protocol.py` defines CRC16-CCITT-FALSE and a proposed
read-only 9-byte LBA request with strict response decoding and rejects
length/CRC/sequence/LBA/status mismatches. No COM port is opened in these
tests; all responses are synthetic fixtures.

Architecture: [SD-05 protocol, pin and test gates](../sd04-directory/SD05_BLOCK_BRIDGE_CONTRACT.md).

**Next gate:** verify the physical UART RX electrical route from the Tang Nano 9K
schematic and the exact pin/bank before adding any Verilog RX module. Preserve
the established SD-04 SRAM candidate and its sector SHA-256.

## Experimental bridge build (NOT a board programming authorization)

The current SD-05 prototype accepts one read-only 9-byte request and sends
523-byte success or 10-byte error replies with CRC16. Its UART receive pin
is FPGA **pin 18**, LVCMOS33, paired with UART TX on pin 17, consistent with
the Tang Nano 9K schematic. The SD-03 pins 36/37/38/39 stay unchanged.

```powershell
cd C:\GitHub\Sipeed-FPGA-LAB05
git pull --ff-only
.\boards\tang-nano-9k\experiments\sd05-lba-bridge\test.ps1
.\boards\tang-nano-9k\experiments\sd05-lba-bridge\build.ps1
```

`test.ps1` currently checks the Python protocol and **RTL compilation only**;
it does NOT yet simulate a UART request through the real RX into the SD
controller and back to UART TX. A compiled design is not proof of correct
serial protocol or response sequencing. A full directed mock-SD UART
simulation and STA report gate must be added/passed before **any** SRAM-only
experiment. The built `.fs` is **not qualified** for programming at this stage.

After those gates and explicit SRAM programming, a read-only PC example will be:

```powershell
python .\boards\tang-nano-9k\experiments\sd05-lba-bridge\tools\sdtool.py --port COM10 --lba 17472 --out root_sd05.bin
```

This command is not suitable for the **SD-04** bitstream, which emits a
one-shot HEX frame and cannot understand the SD-05 binary requests.

## SD-05.1 — host FAT32 file browser (experimental, read-only)

The same SD-05 FPGA bitstream is reused unchanged. On the PC,
`tools/fat32_host.py` adds MBR/BPB validation, FAT32 cluster chain traversal,
long file names with checksum validation and 8.3 fallback, bounded directory
listing and file copy from SD **to a new PC file only**. The Python CLI
never sends CMD24, never opens a raw host disk, and never modifies the SD card.
Safety defaults: 4096 unique sector reads/session, 128 directory sectors,
2 MiB maximum file copy; the copy target must not exist.

From repo root:
```powershell
git pull --ff-only
python -m unittest discover -s .\boards\tang-nano-9k\experiments\sd05-lba-bridge\tests -p "test_*.py" -v
$fat = '.\boards\tang-nano-9k\experiments\sd05-lba-bridge\tools\fat32_host.py'
python $fat --port COM10 info
python $fat --port COM10 ls /
```

**Do not run `get` until the directory listing identifies an intended
regular file.** Later, for one small existing file:
```powershell
python $fat --port COM10 get '/EXAMPLE.TXT' '.\sd05_example_copy.txt'
```

**Acceptance scope:** only source code and synthetic tests have been published;
no hardware listing or file-copy PASS is claimed before operator logs. This
does not certify arbitrary FAT32 variants, damaged media recovery, file
allocation/write operations, or memory-mapped FPGA filesystem hardware.

## SD-05.2: synthetic multicluster verification (not hardware acceptance)

The new tests/test_fat32_multicluster.py models 64-sector (32-KiB) clusters, a fragmented 3-to-7 FAT chain, a 32-KiB+1025-byte file, directory sector boundaries, FAT loops, truncation and safety limits. Run the full Python test suite from the repository root:

    python -m unittest discover -s .\boards\tang-nano-9k\experiments\sd05-lba-bridge\tests -p test_*.py -v

This uses no serial port or card. A physical multicluster PASS still requires a separate pre-prepared test card containing a suitable known file and independent hash; the currently accepted microSD only exposed a 76-byte file. The existing accepted SD-05 FPGA bitstream is unchanged.

See the separate SD-06 CMD24 design gates at ../sd06-cmd24/README.md. No write-capable RTL has been enabled.

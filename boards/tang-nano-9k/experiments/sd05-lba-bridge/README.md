# SD-05 — Python-controlled arbitrary LBA reader (host protocol seed)

**STATUS: Python protocol reference and offline unit tests only.**
No UART RX RTL, pin changes, Gowin build, SRAM programming or SD writes
have been implemented or validated for SD-05.

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

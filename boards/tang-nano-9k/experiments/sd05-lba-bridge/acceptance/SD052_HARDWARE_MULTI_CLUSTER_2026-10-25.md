# SD-05.2 hardware multi-cluster read — operator evidence, 25 October 2026

**VERDICT: physical multi-cluster read PASS on second FAT32 SDHC card, through unchanged SD-05 FPGA bitstream and Python file reader. Fragmentation unknown until FAT chain audit.**

Operator reloaded volatile SRAM with the SD-05 bitstream; Gowin Programmer reported 100% and exit 0.

Second card geometry reported via COM10:
- FAT32 partition LBA 8192
- FAT start LBA 8224
- Data and ROOT start LBA 10142
- 64 sectors/cluster (32 KiB)
- 122721 data clusters.

Root directory contained `SD052.BIN`, size **131073 bytes**, start cluster **6**.

Readback receipt:

```text
SD051_FILE_PASS: BYTES=131073 SHA256=3C7B9082211B55C9FA5697A673EECE6E9B1802C0E1BA4AAB101FDE73FA673846 SECTORS_READ=264
SD051_PC_FILE: SD052_READBACK.BIN
Get-Item .\SD052_READBACK.BIN -> 131073
Get-FileHash .\SD052_READBACK.BIN -Algorithm SHA256 ->
3C7B9082211B55C9FA5697A673EECE6E9B1802C0E1BA4AAB101FDE73FA673846
```

SHA-256 exactly matches the previously prepared reference binary. The file crosses **five clusters** (4 complete 32768-byte clusters plus 1 byte in a fifth). Total unique sectors read including metadata = 264. This is strong functional evidence for host-side FAT cluster chaining and correct final-byte handling.

**What is not yet established:** whether the five clusters are contiguous or fragmented, physical card compatibility across many brands, precise SD SPI external timing closure, raw card write/CMD24, journaling, FAT write correctness. Note that a successful file read necessarily used FAT traversal for multiple clusters, but it does not by itself prove a fragmented chain.

To distinguish contiguous from fragmented, run read-only `tools/fat_chain_audit.py --port COM10 --path /SD052.BIN` and record cluster numbers and discontinuities. Do not modify the original SD-05 card, FPGA Flash or the bitstream.

**Disposition:** SD-05.2 multi-cluster hardware read accepted; FAT fragmentation determination pending.

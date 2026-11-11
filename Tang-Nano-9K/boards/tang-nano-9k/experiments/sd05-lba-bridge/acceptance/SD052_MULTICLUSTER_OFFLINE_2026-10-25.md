# SD-05.2 — multicluster FAT32 offline acceptance, 25 October 2026

**VERDICT: operator-confirmed 13 of 13 Python unit tests PASS; NOT a physical multicluster read certification.**

## Test run and scope

On Windows PowerShell in `C:\GitHub\Sipeed-FPGA-LAB05`, the operator ran:

```powershell
python -m unittest discover -s .\boards\tang-nano-9k\experiments\sd05-lba-bridge\tests -p "test_*.py" -v
```

Exact closing transcript:

```text
test_safety_read_budget_and_file_size (...) ... ok
test_crc_vector (...) ... ok
test_data_and_rejections (...) ... ok
test_range (...) ... ok
test_request (...) ... ok

----------------------------------------------------------------------
Ran 13 tests in 0.016s

OK
```

Prior initial run had one test-harness-only error: `test_directory_across_sector_boundary` specified a 10-sector safety budget despite copying a file of 33,793 bytes (67 data sectors plus FAT32 metadata). The test-only budget was increased to 90; the separate negative 10-sector budget test was retained and passed. No FPGA RTL, accepted bitstream, production FAT32 parser or physical media were changed by this fix (commit `bf8474b65c96559df0ce340cc4964c5307efac4f`).

The synthetic regression covers a 32-KiB FAT32 cluster geometry, fragmented chain 3 -> 7, second-sector directory entry, full source file equality and CRC/protocol negatives. No physical multi-cluster file has been read yet. Existing SD-05 hardware block read and SD-05.1 real 76-byte file access remain separately accepted.

**Next bounded physical gate:** use a dedicated expendable FAT32 MBR SDHC card with an independently hashed deterministic file larger than 128 KiB. Do not write to the original SD-05 accepted card. Read via the existing unchanged SD-05 bitstream with Python `fat32_host.py get`, compare the recovered bytes to the generated reference, and inspect FAT chain length and fragmentation. No SD-06 write bitstream required.

**SD-06** CMD24 research is isolated and specification-only until mock-card write tests, STA, backup/medium-identification gates and explicit operator authorization.

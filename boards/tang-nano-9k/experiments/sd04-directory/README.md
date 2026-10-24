# SD-04 — ROOT sector read-only bridge (development)

Separate experiment; SD-01/02/03 and PiKoSoL v0.2.0 are unchanged.

Goal: use proven SD-03 MBR/VBR detection, then CMD17 on its computed
root directory LBA, output exactly 1024 uppercase ASCII hex characters plus
CRLF at 115200 8N1. Python decodes FAT32 directory records (16 entries per sector).
On scanner/reader failure returns ERROR CRLF, never a fabricated directory.

**Status:** unverified RTL candidate, NOT hardware PASS. No SD writes, no CMD24.

Source dependencies are referenced from the frozen SD-03 snapshot rather than
copied. Run Gowin PnR and inspect setup/hold and external SD MISO timing before
SRAM-only board test. A standalone Python reader follows after a successful
simulation gate.

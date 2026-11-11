# SD-07 — PiKoSoL / PicoRV32 / HDMI / SDHC, FIT-ONLY

**Goal:** measure the **combined** FPGA resources and post-route timing for PiKoSoL v0.2.0 (PicoRV32, 16 KiB ROM, 1 KiB RAM, UART, HDMI 640x480, graphics/TTY CDC) plus SD-05 CMD17 and SD-06 CMD24 sector engines, on Tang Nano 9K GW1NR-9C.

**Status: source candidate only. NO combined Gowin run or timing results have been received; NO hardware PASS.** The separately tested SD-06 remains hardware accepted. This work does not change its RTL or the protected PiKoSoL v0.2.0 release.

## One CLI fit experiment

Checkout `feature/sd07-pikosol-mmio-fit` in the existing local clone, after preserving local work. Do not overwrite a different active branch or uncommitted files.

```powershell
cd C:\GitHub\Sipeed-FPGA-LAB05
git status -sb
git fetch origin
git switch feature/sd07-pikosol-mmio-fit
git pull --ff-only
& .\boards\tang-nano-9k\experiments\sd07-pikosol-mmio\fit.ps1
```

Script uses installed Gowin CLI and the existing verified LAB-04 vendor HDMI/IP/ROM/firmware and SD-06 RTL. New sources are copied into an isolated timestamped build directory. It verifies the PiKoSoL kit, reproducible firmware and pinned HDMI source files before Gowin. Existing LED/UART/graphics and HDMI clock/CDC source remains unchanged. The staged CPU/HDMI source is isolated in this module.

**Deliberately nonprogrammable:** to keep the write path included in the measurement, a synthetic write-enabled LBA 0xFFFFFFFE is passed to the new `sd07_sd_mmio`. This would be unsafe for a real card; the script **always removes every `.fs`** after running Gowin. NEVER program a fit-only image or remove this guard.

## SD MMIO ABI proposal (CPU system-clock domain)

Base: `0x20000200`. Existing LED `0x20000000`, UART `0x20000010` and graphics `0x20000100` remain unchanged.

| Offset | Access | Function |
|---|---|---|
| `+00` | RW | 32-bit LBA |
| `+04` | WO | 1=CMD17, 2=CMD24, 4=reset buffers |
| `+08` | RO | busy, done, error, initialized, original/new data ready, write allowed, valid read, verified write |
| `+0C` | RO | Error code |
| `+10` | RW | Read index 0..511 |
| `+14` | RO | Last read-sector byte, one synchronous BRAM pipeline |
| `+18` | WO | Append one new-sector byte (512 total) |
| `+1C` | WO | Append one original-sector preimage byte (512 total) |
| `+20` | RO | Constant `0x53443037` ('SD07') |

Initial implementation only: 32-bit aligned full-word MMIO access, no DMA, no native file I/O or FAT32 changes, no new CPU firmware command. CPU would use the registers when future software is added.

## Decision gate

- **FIT**: Gowin PnR completes, usage `<=` available GW1NR-9C resources, all physically reported setup/hold/recovery/removal slacks are positive, no unresolved route/CDC constraints. Full existing `check_sta_v018b.py` must still pass on this specific build; an observed zero violated endpoint summary alone is NOT enough.
- **NO FIT**: synthesis error RP0006, failed routing, depleted resources or timing blockers. Record actual metrics and stop rather than rewriting working modules. Consider a measured lean SD design or Tang Nano 20K.
- **No bitstream / board programming at this stage**, even on fit PASS. Firmware + CPU MMIO functional tests and then an explicitly write-disabled physical image are distinct later steps.

Practical note: PiKoSoL v0.2.0 has a working HDMI video pipeline and a published bitstream already hardware accepted. Do not replace it with this work-in-progress.

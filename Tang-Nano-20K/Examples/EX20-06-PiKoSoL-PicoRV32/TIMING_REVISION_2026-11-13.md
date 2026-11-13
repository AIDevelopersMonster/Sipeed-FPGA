# EX20-06 / PiKoSoL 20K — timing closure revision 2 (13.11.2026)

**STATUS: NEW RTL CANDIDATE, NOT A GOWIN STA PASS AND NOT A BOARD PASS.**

Previous candidate `candidate_20261113_154145_852` completed PnR but missed 720p 74.25MHz: pixel Fmax 56.145MHz, setup WNS -4.343ns, three CDC hold paths -0.938/-0.938/-0.703ns, recovery WNS -3.447ns on DVI OSER10, `PR1014` generic clock routing. The evidence was retained in `evidence/PNR_STA_AUDIT_2026-11-13.md`.

## Architectural corrections in this revision

- **Renderer:** no 9K crop. Still 1280x720, 160x60 visible glyph cells (160x64 ring storage) and eight objects with frame-snapshot updates. Four-pixel-clock pipeline from source raster to DVI, with matching `HS/VS/DE`: coordinate flop; independent eight parallel object hit flops; priority/hud and synchronous BSRAM read; synchronous font ROM and final color alignment. Per-object end/border coordinates are precomputed at frame commit; compare-only per-pixel geometry instead of subtraction and eight serial color decisions. Original source's RAM has one synchronous write port; preserve BSRAM.
- **Reset:** new `pikosol20k_reset_ctrl.v`; PLL lock loss and button reset assert all domains, serializer reset released in serial clock domain, CPU reset qualified in 27MHz, pixel reset released in pixel domain. DVI reset and CLKDIV reset are no longer driven by a CPU-domain release flop. Vendor PHY reset semantics and recovery/removal must be confirmed by new Gowin reports; this is a hypothesis to validate.
- **CDC:** existing lossless toggle handshakes retained. Staged copies of the three 9K mailboxes get `async_reg=true` on both sync stages. SDC adds six narrowly targeted first-stage pin exceptions, **not** a blanket exception between clocks. Beware: Gowin may reject some wildcard pin patterns; a constraint is not assumed valid until all six appear as `Actived` and the protected synchronous paths are still analyzed.
- **Tests:** changed renderer regression (eight object priority, boundaries, LED HUD and commit), reset-domain regression with PLL-loss/button, and new conservative STA gate. Original `.fs` is not modified.

## Windows reproduction (isolated worktree, no FPGA programming)

```powershell
Set-Location C:\GitHub\Sipeed-FPGA-PiKoSoL20K
git status --short
git fetch origin
# Only when git status --short is empty; do NOT overwrite local edits
git switch --detach origin/feature/pikosol-20k-picorv32-port
Set-Location .\Tang-Nano-20K\Examples\EX20-06-PiKoSoL-PicoRV32
python .\tests\test_contract.py
.\tests\run_sim.ps1
# If BOTH Icarus regressions pass:
.\build.ps1
# Always inspect actual Gowin output:
.\tools\collect_sta.ps1
```

The known Icarus binaries on the operator's PC live at `C:\msys64\ucrt64\bin\iverilog.exe` and `vvp.exe`; `run_sim.ps1` finds them automatically.

`collect_sta.ps1` parses the *latest* candidate, creates `build/EX20-06_STA_candidate_<timestamp>.zip` and exits after producing a `STA_GATE.json` decision. A reported `PASS_FOR_IO_REVIEW_NOT_BOARD` is **not** a green light for SRAM loading: independently review pin electrical constraints (particularly reset pin 88), `PR1014`, CDC protocol/bundled-data hold, reset recovery, setup margin and the complete generated `.fs` SHA256. **Never flash the FPGA.**

## Explicit acceptance

`FAIL` if any: setup/hold violation count nonzero; setup/hold/recovery/removal WNS negative; pix_clk Fmax below 74.25MHz; fewer than six CDC SDC exceptions matched/active; missing ROM HEX; IF0008; Gowin failure. If the STA gate exits nonzero, archive the evidence, do not program, and analyze the new worst route. Repeat until no unqualified exceptions or blockers remain.

**Testing limitations:** Python syntax and static architecture checks can run in the assistant environment, but the assistant has no Windows Gowin or local Icarus binary. **This document is not an assertion that either updated RTL simulation or new Gowin PnR was run.**

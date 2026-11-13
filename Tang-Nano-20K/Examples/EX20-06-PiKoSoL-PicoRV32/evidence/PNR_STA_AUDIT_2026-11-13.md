# EX20-06 PiKoSoL 20K / PicoRV32 — Gowin PnR and STA audit (2026-11-13)

**HARDWARE GATE: BLOCKED — NO SRAM PROGRAMMING OF THIS CANDIDATE YET.**

Source evidence: operator-provided archive `PiKoSoL20K_PNR_REPORTS.zip`, candidate `candidate_20261113_154145_852`; Gowin **V1.9.9 Beta-4 Education**, device **GW2AR-LV18QN88C8/I7**, report generated **Fri Nov 13 15:42:38 2026**. This is an inspection of actual generated implementation reports, not a claim that the FPGA was tested or that the supplied bitstream was personally retrieved.

## Build and memory

- `gowin.log`: GowinSynthesis finish; placement and routing completed; **bitstream generation completed**; no `IF0008` or `EX3988` in this log. A generated `.fs` is implied, but **not included in the supplied archive**, so actual file presence, SHA256 and file validity are **NOT VERIFIED**.
- PnR logic: **4699/20736 (23%)**; 3119 LUT, 1460 ALU, 20 SSRAM/RAM16 cells; **2367/15750 registers (16%)**; **3576/10368 CLS (35%)**.
- Physical BSRAM: **30/46 (66%)** = **14 SDPB + 16 pROM**. The 131072-DFF `text_mem` inference failure from an earlier candidate is gone. Do not equate the 30 blocks exclusively with text memory: ROM, shell RAM and other arrays share these resources.
- DSP **0**, PLL **1/2**, CLKDIV **1/8**, OSER10 **4**. Resource fit is successful, but remaining BSRAM (16/46) is not a commitment that a future SDRAM controller, filesystem, audio and video DMA will all fit without re-architecture.

## Actual STA results — acceptance failed

| Parameter | Observed | Interpretation |
|---|---:|---|
| `clk27` target | 27.000 MHz | CPU domain |
| `clk27` Fmax | **89.422 MHz** | Reported sufficient margin for 27 MHz |
| `pix_clk` target | **74.250 MHz** (period 13.468 ns) | 1280×720/60 DVI timing requirement |
| `pix_clk` Fmax | **56.145 MHz** | **FAIL** versus required 74.25 MHz |
| Worst pix setup | **-4.343 ns** | **FAIL**, 15 logic levels; route/input delay about 17.776 ns |
| pix setup endpoint TNS | **-89.367 ns**, 24 endpoints in per-clock summary | **FAIL** |
| STA global setup violated endpoints | **104** | Reported by global `STA Tool Run Summary`; different grouping from per-clock TNS endpoint count |
| Hold path 1 | **-0.938 ns** | Pixel-to-CPU CDC ACK: `u_scene/u_byte_cdc/ack_pixel` → `ack_meta_sys` |
| Hold path 2 | **-0.938 ns** | Pixel-to-CPU CDC ACK: `u_led_cdc/ack_pixel` → `ack_meta_sys` |
| Hold path 3 | **-0.703 ns** | Pixel-to-CPU CDC ACK: `u_graphics_cdc/ack_pixel` → `ack_meta_sys` |
| Worst recovery | **-3.447 ns** | CPU-release reset to DVI `OSER10` reset at high-speed generated clock |
| Removal | First reported paths positive (~+0.925 ns) | Does **not** cancel recovery failure |
| Exceptions | **No timing exceptions to report** | Only base SDC clocks present; CDC constraint strategy needs review |

**Worst setup route:** `hcount_3_s0/Q` → `u_scene/background_a_0_s12/DI[3]`, both on `pix_clk`. Worst total reported data delay **17.776 ns**, target **13.468 ns**, slack **-4.343 ns**. The source RTL combines pixel coordinate transformation, all-object geometry tests, border/checker conditions and priority color selection before `background_a`. This suggests a physical **video combinational path**, not a PicoRV32 CPU Fmax limitation.

**CDC hold interpretation:** these are crossings between different clock domains, handled in RTL by handshake/synchronizers. Negative hold numbers in a report which has no appropriate CDC exceptions are a **STA signoff blocker**, not automatically proof of malfunction. Independently validate the CDC protocol, then constrain **only** legitimate asynchronous first-stage crossings and bundled-data handshakes. **Do not apply blanket false paths** to the video pipeline or entire clocks.

**Recovery:** `cpu_release_1_s0/Q` → `u_hdmi/rgb2dvi_inst/u_OSER10_* /RESET` crosses from the 27 MHz release into the fast DVI serializer. Correct the reset architecture and verify recovery/removal, rather than waiving a documented violation. Review resetting HDMI PHY from PLL lock separately from pixel-domain logic reset; synchronize deassertion in the receiving domain where allowed by the vendor primitive.

## Other observations / risks

- `gowin.log` warning `PR1014`: `clk27_d` uses generic routing resources for a clock. This deserves a clock-tree and routing inspection; despite CPU Fmax margin it is **not** a clean-clock PASS.
- Pin report `reset_btn` pin 88 is `LVCMOS33` with reported `BankVccio=1.2`; verify bank electrical configuration against the target board / vendor constraints, rather than assuming pinout is electrically accepted merely because PnR succeeded.
- Power report estimates **266.560 mW total** at assumptions configured in the report. It is **not a measured board current** and must not be treated as hardware proof.
- `report_timing` has no false-path or CDC exceptions. Adding exceptions without verifying their narrow applicability would only conceal errors.
- No SDRAM controller, SD card or optional RGB LED/audio was present in this candidate. Future modules may change resource and timing closure.

## Next controlled iteration

1. **VIDEO PIPELINE:** separate per-object geometry hit tests from final priority/RGB selection with a register stage; eliminate unnecessary subtraction from the critical input cone if required. Align font/text data, HDMI `HS/VS/DE` to the new latency; add a test for pixel-edge alignment and eight overlapping sprites. Preserve **native 1280x720** and **160x60 terminal**.
2. **RESET/CDC:** separate PLL/serializer reset from CPU reset, review every source/synchronizer crossing and DVI reset release. Constrain valid asynchronous crossings narrowly, and re-run recovery/hold after changes.
3. **CLOCK/IO:** inspect `PR1014`, explicitly verify pin 88 bank Vccio and DVI LVDS pins. Do not change FPGA flash.
4. **REBUILD & DIFF:** run Icarus, Gowin synthesis+PnR+full STA with the same part, clocks and source SHA. Require `WNS setup ≥ 0`, `TNS = 0`, justified hold/recovery/removal signoff, correct ROM/BSRAM, no critical route/IO issues. Record SHA256 of `.fs` separately.
5. **ONLY THEN BOARD:** obtain first SRAM-only board evidence: HDMI image/geometry, PicoRV32 UART `PiKoSoL>`, six physical LEDs, reset behavior. Do not call the current image `BOARD PASS`.

No 9K limitations are restored or accepted as fixes. The current `P&R completed` message is not evidence of timing closure.

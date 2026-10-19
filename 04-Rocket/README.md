# 04 — Rocket (conditional)

**Status: feasibility only. No board / synthesis results for Primer 25K.**

Target candidate: Sipeed Tang Primer 25K (GW5A). Main Rocket implementation: [`chipsalliance/rocket-chip`](https://github.com/chipsalliance/rocket-chip). Reference port: [`sipeed/TangPrimer-20K-example/rocket`](https://github.com/sipeed/TangPrimer-20K-example/tree/main/rocket), via OpenRigil generated RTL.

## Verified reference limitations

The Sipeed Primer **20K** Rocket example is a reduced RV32IC system with UART printing the character `A`. Its published run reports **13,106 / 20,736** logic cells and ~**39.7 GB** peak host memory during PnR. That is an author-supplied result on a *different FPGA and toolchain*, not a prediction for Primer 25K. The author removed features to fit and workaround synthesis limitations.

## Gate R1 before implementation

1. Fix Rocket generator/Scala/Chisel and Yosys/Gowin versions with immutable commits.
2. Select a minimal RV32I or RV32IC feature set, deliberately exclude caches/FPU/debug not needed.
3. Simulate the generated RTL independently of target board.
4. Try synthesis on GW5A, capture device-native cell types and worst resource.
5. Only after PnR/STA succeeds create actual peripheral adapter and firmware test.

If fit, timing, power, build-host RAM or tools are unacceptable, record **NOT_FEASIBLE** with evidence instead of claiming successful migration.

**Non-claim:** Rocket cannot be assumed to fit just because the 20K reference did. A clock/CPU benchmark would be invalid without controlling cache/ISA/memory differences.

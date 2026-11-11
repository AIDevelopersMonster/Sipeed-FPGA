# Peer review checklist

- [ ] Architectural goal and excluded claims clearly stated.
- [ ] CPU source pin resolves to real immutable Git object.
- [ ] Third-party licenses retained; dependencies not silently copied.
- [ ] Correct physical chip package/clock/pin voltage/IO assignment.
- [ ] Boot source and generated ROM exactly match (hash or independent check).
- [ ] Complete UART 8N1 decoding passes, not only MMIO write pulse checks.
- [ ] Correct native CPU handshake for held/retried/partial accesses.
- [ ] Reset, simultaneous writes, timer wrap, unmapped addresses and timeouts are tested.
- [ ] No unintended latches, no unconstrained clocks, no cross-domain hazards.
- [ ] LUT/FF/BRAM/DSP and STA reports saved with toolchain versions.
- [ ] Real board observed behavior documented independently of RTL simulation.
- [ ] Comparisons do not conflate CPU-only area with complete SoC or 27MHz with 50MHz target.

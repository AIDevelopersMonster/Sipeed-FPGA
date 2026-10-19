# Architectural decisions (ADR)

### ADR-001 — one project repository

- Decision: single independent `AIDevelopersMonster/Sipeed-FPGA` monorepo, one implementation per numbered top-level folder.
- Rationale: common contracts/tests, easier comparison and atomic changes.
- Out of scope: modifying `DDF`, MAX 10 or unrelated repositories.
- Status: adopted for bootstrap; repository has not yet been created remotely by these files.

### ADR-002 — reference pinning, no copied CPU IP

- Pin reference commits in `sources.lock.json`; fetch only required CPU for local build.
- Preserve each upstream license and attribution.
- No large binary FPGA bitstreams committed by default.

### ADR-003 — verify claims separately

- Model / RTL simulation / PnR / physical board / benchmark each have separate exit criteria.
- No promised universal bitstream or direct CPU equivalence.

### ADR-004 — stages use actual available boards

- Nano 9K: PicoRV32, NEORV32; Primer 25K: LiteX/VexRiscv, Rocket feasibility.
- Primer 20K is reference material only, not assumed available for real tests.

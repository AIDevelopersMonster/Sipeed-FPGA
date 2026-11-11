# PicoRV32 LAB-03.1 — real bus-event trace recorder (RTL prototype)

**Status: SOURCE_PREFLIGHT_PASS · TRACE_UNIT_RTL_PASS · SOC_TRACE_RTL_PASS · RTL_PASS (local Icarus Verilog, 20 October 2026). Gowin PnR/STA and FPGA BOARD remain NOT TESTED for LAB-03.1.**

LAB-03.1 is a non-intrusive trace-capture component and two RTL testbenches. It observes the **unchanged LAB-02** PicoRV32 SoC. It is **not wired into the synthesized board image** and it has **no UART trace-download command yet**. Do not label the board or Gowin stages PASS on the basis of this package.

- [Описание и протокол RU](LAB03_1_TRACE_RU.md)
- [Specification and record EN](LAB03_1_TRACE_EN.md)
- [Trace RTL](../../01-PicoRV32/rtl/lab03_trace_capture.v)
- [Isolated testbench](../../01-PicoRV32/tests/tb_lab03_trace_capture.v)
- [PicoRV32 + LAB-02 ROM integration testbench](../../01-PicoRV32/tests/tb_lab03_soc_trace.v)
- [PowerShell RTL test runner](../../01-PicoRV32/tools/test_lab03_1.ps1)

## Windows PowerShell (root `C:\GitHub\Sipeed-FPGA`)

```powershell
& .\01-PicoRV32\tools\fetch_picorv32.ps1
& .\01-PicoRV32\tools\test_lab03_1.ps1 -UnitOnly
& .\01-PicoRV32\tools\test_lab03_1.ps1
```

**Observed output (user-provided Windows PowerShell / Icarus Verilog, 20 October 2026):**

```text
LAB03_1_SOURCE_PREFLIGHT_PASS: source, TBs, 1 KiB LAB-02 ROM; NOT RTL/PNR/BOARD
LAB03_1_TRACE_UNIT_RTL_PASS: triggers, accepted transfers, readback, full, exact-fit, overlap
ASSEMBLE PASS: 118 instructions, 1024 B ROM, labels=22
LAB03_1_SOC_TRACE_RTL_PASS: command=4, events=22 fetches=21 LED_STORE=0x8, verified boot.hex and L=4
LAB03_1_RTL_PASS: recorder and real PicoRV32-SoC trace. FPGA PnR/BOARD NOT TESTED.
```

The `-UnitOnly` test also returned `LAB03_1_UNIT_RTL_PASS ONLY`. Nonfatal Icarus `timescale` and PicoRV32 `@*` sensitivity warnings appeared; the PASS markers above are observed RTL simulation results. The 21 FETCH events are accepted instruction reads, **not** evidence of 21 retired instructions. No independent GitHub Actions rerun is claimed.

## Scientific boundary

**FETCH** means an **acknowledged instruction read**, not an instruction retirement. **LED_WRITE** means an acknowledged MMIO write, not an optical measurement. The UART trigger is the receiver's valid byte, not proof the CPU consumed the FIFO. An explicit `truncated` or `overlap` flag invalidates completeness. Buffers do not silently wrap.

**Next milestone LAB-03.2:** use a versioned readout transport and a synthesized SoC integration, followed by Gowin PnR/STA and physical testing. The existing LAB-02 source and firmware remain unchanged in LAB-03.1.

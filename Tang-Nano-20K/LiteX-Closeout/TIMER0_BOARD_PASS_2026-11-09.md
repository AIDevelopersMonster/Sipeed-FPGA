# Tang Nano 20K — Timer0 BOARD PASS (2026-11-09)

**Evidence source:** operator-provided verbatim JSON output from physical Tang Nano 20K, factory LiteX / VexRiscv_Min, COM25. Local timestamp `2026-11-09T00:18:17.450536`. This record preserves the reported values without claiming an independent repeat of the experiment.

**Script:** [timer0_bios_test.py](timer0_bios_test.py), `--run --port COM25`.
**Local evidence:** `C:\GitHub\Sipeed-FPGA-LAB20-6\Tang-Nano-20K\LiteX-Closeout\evidence\TIMER_TEST_20261109_001817_450536.json` (exact filename should be checked locally; JSON content supplied in conversation).
**Backup:** `TIMER_BACKUP_20261109_001817_450482.json`.

## Observed JSON results

| Field | Reported value |
|---|---|
| status | `TIMER0_BOARD_PASS` |
| base CSR | `0xF0002800` |
| factory ROM fingerprint | Five addresses verified |
| configured one-shot | 144000000 ticks, nominal 3 s @ 48 MHz |
| first latched count | 143712764 |
| second latched count | 128384999 |
| final count | 0 |
| host elapsed time | 3.052 s |
| event_status_at_zero | 1 |
| oneshot_pass | true |
| restore_pass | true |
| restore_errors | [] |
| direct_irq_enable | false |
| flash_writes | false |

Original configuration and restored readback match exactly:
`load=12000000, reload=0, en=1, ev_pending=1, ev_enable=0`; original VALUE was 0.

**Conclusion:** on the operator's real board, Timer0 demonstrated countdown, terminal zero, event assertion, and restoration of the original configuration. **TIMER0 BOARD PASS**, limited to one-shot operation and non-IRQ polling. This does **not** independently establish a periodic reload test or a custom interrupt handler.

**Boundaries:** no FPGA Flash write; no direct IRQ enable. The test does write to Timer0 MMIO, then restores its configuration. The backup and raw test JSON remain local on the operator's Windows PC; only the transcription above is in GitHub.

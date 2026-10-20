# PicoRV32 LAB-02 — USB UART and synchronized LED teaching demo

**20 October 2026 | Tang Nano 9K | 27 MHz | Hardware tested**

PicoRV32 RV32I executes an **118-instruction ROM firmware** to receive characters over the board's built-in USB UART (115200 8N1), write the LED MMIO register, read it back, and acknowledge via UART TX. A separate **four-instruction / 19-educational-step** HTML visualization issues a board command at step 14 and waits for `L=n` before displaying the hardware state. Stepping backward switches the physical LED off, and advancing switches it on again. This is event-and-acknowledgment synchronization, **not cycle-accurate CPU tracing**.

**Tested:** `MODEL_PASS · RTL_PASS · PNR_PASS · STA_PASS · BOARD_PASS · HTML_HARDWARE_PASS`.

**STA:** clock 27.000 MHz, Fmax 52.522 MHz, setup/hold TNS 0, minimum setup slack +17.997 ns, hold slack +0.563 ns.

## Методические указания / Methodical guides

| Language | Markdown (full instructions and protocols) | Printable PDF (7 pages) | Hardware-linked HTML |
|---|---|---|---|
| Русский | [LAB02_UART_RX_RU.md](../LAB02_UART_RX_RU.md) | [PDF RU](PicoRV32_LAB02_Methodical_RU_v1.0.pdf) | [HTML RU](../interactive/picorv32-led1/linked/PicoRV32_LED1_Linked_RU.html) |
| English | [LAB02_UART_RX_EN.md](../LAB02_UART_RX_EN.md) | [PDF EN](PicoRV32_LAB02_Methodical_EN_v1.0.pdf) | [HTML EN](../interactive/picorv32-led1/linked/PicoRV32_LED1_Linked_EN.html) |

## Repeat on Windows / Повторить на Windows

In `C:\GitHub\Sipeed-FPGA`, on the LAB-02 code:

```powershell
& .\01-PicoRV32\tools\test_lab02.ps1 -ModelOnly
& .\01-PicoRV32\tools\test_lab02.ps1
& .\01-PicoRV32\tools\build_gowin.ps1
```

Inspect `impl/pnr` PnR and STA reports, then configure **volatile SRAM only**, not flash. Board USB UART is COM10 in the completed test (on other machines its COM number may differ). Test with:

```powershell
& .\01-PicoRV32\tools\probe_lab02_serial.ps1 -PortName COM10
& .\01-PicoRV32\tools\launch_lab02_html.ps1 -Language RU
```

Open the URL printed by `launch_lab02_html.ps1` in Chrome or Edge and grant **Web Serial** access. Close other serial terminals while the browser owns the port. See full Markdown guides for the test protocol and limitations.

**Evidence:** The author directly observed L1, L4, L6 and LEDs off in manual UART tests; the linked HTML was tested in manual, automatic and backward/forward modes using three selected LEDs. Not every possible browser, device or serial timing condition was tested. `L=n` confirms MMIO readback, not an optical measurement. The independently visualized four-instruction ROM image is *not* the 118-instruction firmware actually flashed into FPGA SRAM.

**Experiment:** A. A. Malachevsky / Малачевский А. А. ([ORCID](https://orcid.org/0009-0008-6009-3196)). **Upstream CPU:** PicoRV32 by Claire Xenia Wolf, ISC license.

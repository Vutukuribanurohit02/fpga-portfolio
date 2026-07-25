\# Project 1 — UART / APB Peripheral



A configurable UART transmitter/receiver wrapped in an AMBA APB register interface, designed, formally simulated, synthesized, and deployed to real Nexys A7 (Artix-7 XC7A100T) hardware.



\---



\## Architecture



\### Register Map (APB Slave)

| Address | Register | Access | Description |

|---|---|---|---|

| `0x00` | TXDATA  | R/W | Write triggers UART transmission of the byte |

| `0x04` | RXDATA  | R   | Last byte received over UART |

| `0x08` | STATUS  | R   | Bit 0 = `tx\_busy`, Bit 1 = `rx\_valid` |

| `0x0C` | BAUDDIV | R/W | Baud rate divider value |



\### Module Breakdown

\- \*\*`uart\_apb.sv`\*\* — APB slave: register decode, read/write logic, instantiates the modules below

\- \*\*`baud\_gen.sv`\*\* — 16× oversampled baud rate generator (clock divider)

\- \*\*`uart\_tx.sv`\*\* — FSM-based TX shift register (IDLE → START\_BIT → DATA\_BITS → STOP\_BIT)

\- \*\*`uart\_rx.sv`\*\* — FSM-based RX shift register with 2-flop input synchronizer (metastability protection) and mid-bit sampling for timing robustness

\- \*\*`nexys\_uart\_top.sv`\*\* — Board-level wrapper mapping switches/buttons/LEDs to the APB interface for a physical hardware demo



\---



\## Verification



\### Self-Checking Testbenches (SystemVerilog, simulated in Vivado XSim)



\*\*`uart\_tx\_tb.sv`\*\*

\- 4 test patterns: `0xA5`, `0x00`, `0xFF`, `0x55`

\- Checks: start bit, all 8 data bits, stop bit, return-to-idle for each pattern

\- \*\*Result: 44/44 checks passed, 0 errors\*\*



\*\*`uart\_rx\_tb.sv`\*\*

\- Bit-bangs full UART frames onto `rx` at the baud rate, checks decoded byte matches expected value

\- Same 4 test patterns as TX

\- \*\*Result: 4/4 checks passed, 0 errors\*\*



\### Debugging notes (for anyone reading the commit history)

\- Fixed a simulation race condition where the testbench sampled `tx` in the same delta-cycle as the DUT's `always\_ff` update — resolved by adding a full clock-edge delay (`@(posedge clk); #1;`) before every sample point

\- Fixed an RX testbench issue where `rx\_valid`'s single-cycle pulse could be missed if the test sequence was mid-instruction when it fired — resolved with a continuously-running `always\_ff` latch (`valid\_seen` / `captured\_data`) that catches the pulse regardless of simulation timing



\---



\## Hardware Implementation



\- \*\*Toolchain:\*\* Vivado ML Standard Edition (Xilinx/AMD)

\- \*\*Target:\*\* Digilent Nexys A7-100T (Artix-7, `xc7a100tcsg324-1`)

\- \*\*Synthesis:\*\* 0 errors

\- \*\*Implementation:\*\* 0 errors, 0 failing timing endpoints (WNS 3.875 ns positive slack across 105 endpoints)

\- \*\*Resource utilization:\*\* LUT 1%, FF 1%, IO 16%, BUFG 3% — extremely lightweight design

\- \*\*Power:\*\* 0.101 W total on-chip, 25.5°C junction temperature (simulated)

\- \*\*Bitstream:\*\* generated and successfully programmed onto physical hardware (confirmed via DONE LED and Vivado Hardware Manager status)



\### Pin Constraints (`nexys\_uart.xdc`)

Maps `CLK100MHZ`, `CPU\_RESETN`, `SW\[15:0]`, `LED\[15:0]`, `BTNC`, and UART `tx`/`rx` (routed to Pmod JA pins 1 and 2 for physical loopback testing) to the Nexys A7's physical pins.



\### Board-Level Demo Interface (`nexys\_uart\_top.sv`)

Since the raw APB bus isn't practical to drive with switches, this wrapper translates:

\- `SW\[3:0]` → APB register address

\- `SW\[11:4]` → write data byte

\- `SW\[15]` → read/write mode

\- `BTNC` → triggers a single APB transaction (setup + access phase)

\- `LED\[15:0]` → displays `PRDATA` (register read result)



\---



\## Status



| Milestone | Status |

|---|---|

| RTL design | ✅ Complete |

| Self-checking testbenches | ✅ Complete (48/48 total checks passed) |

| Synthesis | ✅ Complete, 0 errors |

| Implementation | ✅ Complete, 0 errors, timing met |

| Bitstream generation | ✅ Complete |

| Programmed onto physical hardware | ✅ Confirmed (DONE LED, Hardware Manager) |

| Physical switch/LED loopback demo | ⚠️ Attempted — hardware confirmed running correctly (DONE LED, MODE jumper corrected to JTAG), but LED-based visual confirmation was inconclusive via photos |

| Live ILA-based signal verification | 🟡 In progress — setting up a debug core in Vivado to observe `PRDATA` and `rx\_valid` directly, removing the need for photo-based LED interpretation |



\*\*Key learnings documented for this project:\*\*

\- MODE jumper on the Nexys A7 must be set to \*\*JTAG\*\* (not QSPI or USB/SD) for the board to reliably hold a JTAG-programmed bitstream; otherwise it can revert to the factory demo stored in flash

\- The board's PROG button reloads from flash, not JTAG memory — should be avoided once a JTAG bitstream is loaded

\- 7-segment display behavior is not a reliable indicator of "is my design running," since this design never drives it — undriven pins can show ambiguous ghosting



\---



\## Source Files


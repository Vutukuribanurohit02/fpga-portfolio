\# Banu Rohit Vutukuri — RTL / Hardware Engineering Portfolio



\*\*Live site:\*\* \[vutukuribanurohit02.github.io/fpga-portfolio](https://vutukuribanurohit02.github.io/fpga-portfolio/)

\*\*LinkedIn:\*\* \[linkedin.com/in/banurohit-vutukuri](https://www.linkedin.com/in/banurohit-vutukuri/)

\*\*Email:\*\* vutukuribanurohit02@gmail.com



\---



I build digital hardware from the register level down to the bitstream — writing SystemVerilog RTL, proving correctness with self-checking testbenches and formal methods, and validating every design on real FPGA hardware before calling it done.



This repo tracks that process end-to-end: \*\*spec → RTL → simulation → synthesis → silicon.\*\* Each project below is built independently, verified rigorously, and — where possible — pushed all the way to physical hardware, not left as a simulation-only exercise.



\---



\## Toolchain



| Category | Tools |

|---|---|

| RTL | SystemVerilog |

| Synthesis / Implementation | Vivado ML Standard Edition (Xilinx Artix-7) |

| Simulation | Vivado Simulator (XSim), Icarus Verilog, Verilator |

| Formal Verification | SymbiYosys |

| ASIC Flow | Yosys, OpenLane, OpenROAD, KLayout |

| Hardware | Digilent Nexys A7 (AMD Artix-7 XC7A100T) |



\---



\## Projects



\### ✅ Project 1 — UART / APB Peripheral

\*\*\[View source →](./project1-uart)\*\*



A configurable UART transmitter/receiver wrapped in an AMBA APB register interface — the first building block toward a full SoC.



\- \*\*Register map:\*\* `0x00` TXDATA · `0x04` RXDATA · `0x08` STATUS · `0x0C` BAUDDIV, implemented as a clean APB slave

\- \*\*Design:\*\* 16× oversampled baud rate generator, FSM-based TX and RX shift registers, 2-flop synchronization on the RX input to guard against metastability

\- \*\*Verification:\*\* Self-checking SystemVerilog testbenches — \*\*44/44 TX checks\*\* and \*\*4/4 RX checks passed\*\* across four data patterns (0xA5, 0x00, 0xFF, 0x55)

\- \*\*Hardware validation:\*\* Synthesized, implemented, and \*\*programmed onto a real Nexys A7 (Artix-7 XC7A100T)\*\* via a board-level wrapper (`nexys\_uart\_top.sv`) driven by switches and LEDs for a live APB read/write demo

\- \*\*Status:\*\* RTL complete, formally simulated, running on real hardware. Physical UART loopback (jumper-wire) test pending.



\### 🟡 Project 2 — Async FIFO with Formal CDC Proof

\*In progress\*



A clock-domain-crossing FIFO with correctness proven formally via SymbiYosys, not only simulated — the verification depth most student portfolios skip.



\### ⚪ Project 3 — RV32I ALU

\*Planned\*



Formally verified arithmetic logic unit — the first functional block of a from-scratch RISC-V core.



\### ⚪ Project 4 — Single-Cycle RV32I CPU

\*Planned\*



A single-cycle RV32I processor capable of running compiled C — the flagship project tying every earlier piece together.



\---



\## Stretch Goals



\- \*\*Research paper reimplementation\*\* — applying the methodology from Weingarten, Datta, Kole \& Drechsler, \*"Complete and Efficient Verification for a RISC-V Processor Using Formal Verification,"\* DATE 2024, to a self-built RV32I core: extending formal proofs beyond the ALU into full sequential correctness.

\- \*\*Tiny Tapeout silicon submission\*\* — fabricating a compact verified module on the SkyWater SKY130 process via the TTSKY26c shuttle.



\---



\## Contact



\*\*Banu Rohit Vutukuri\*\*

\[LinkedIn](https://www.linkedin.com/in/banurohit-vutukuri/) · \[vutukuribanurohit02@gmail.com](mailto:vutukuribanurohit02@gmail.com)


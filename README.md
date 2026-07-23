\# FPGA/RTL Portfolio — Banu Rohit Vutukuri



Digital design portfolio built for hardware/ASIC/verification engineering roles, targeting semiconductor and EDA companies (AMD, Qualcomm, Arm, Synopsys, Cadence, Tenstorrent, NVIDIA).



\## Toolchain

\- \*\*RTL:\*\* SystemVerilog

\- \*\*Synthesis/Implementation:\*\* Vivado ML Standard Edition (Xilinx Artix-7)

\- \*\*Simulation:\*\* Vivado Simulator (XSim), Icarus Verilog, Verilator

\- \*\*Formal Verification:\*\* SymbiYosys

\- \*\*Hardware:\*\* Digilent Nexys A7 (AMD Artix-7 XC7A100T)



\## Projects



\### Project 1 — UART/APB Peripheral ✅

A configurable UART transmitter/receiver with an AMBA APB register interface.



\- \*\*Register map:\*\* `0x00` TXDATA, `0x04` RXDATA, `0x08` STATUS, `0x0C` BAUDDIV

\- \*\*Design:\*\* APB slave decode logic, 16x-oversampled baud rate generator, FSM-based TX/RX shift registers with 2-flop synchronization on RX input

\- \*\*Verification:\*\* Self-checking SystemVerilog testbenches for TX (44/44 checks passed) and RX (4/4 checks passed) across multiple test patterns (0xA5, 0x00, 0xFF, 0x55)

\- \*\*Hardware validation:\*\* Synthesized, implemented, and programmed onto a Nexys A7 (XC7A100T) via a board-level wrapper (`nexys\_uart\_top.sv`) using switches/LEDs for a live APB read/write demo

\- \*\*Status:\*\* RTL complete, formally simulated, running on real hardware. Physical UART loopback test pending (jumper wire).



\[→ View Project 1 source](./project1-uart)



\### Project 2 — Async FIFO with Formal CDC Proof (in progress)

Clock-domain-crossing FIFO with a SymbiYosys formal proof of correctness.



\### Project 3 — RV32I ALU, Formally Verified (planned)



\### Project 4 — Single-Cycle RV32I CPU (planned)

Runs compiled C.



\## Stretch Goals

\- \*\*Research paper reimplementation:\*\* Applying methodology from Weingarten et al., DATE 2024 ("Complete and Efficient Verification for a RISC-V Processor Using Formal Verification") to a self-built RV32I core.

\- \*\*Tiny Tapeout submission:\*\* Silicon fabrication of a compact verified module via the TTSKY26c shuttle.



\## Contact

\[LinkedIn / email — add your links here]


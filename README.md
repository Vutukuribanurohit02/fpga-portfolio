# Banu Rohit Vutukuri — RTL / Hardware Engineering Portfolio

**Live site:** [vutukuribanurohit02.github.io/fpga-portfolio](https://vutukuribanurohit02.github.io/fpga-portfolio/)
**LinkedIn:** [linkedin.com/in/banurohit-vutukuri](https://www.linkedin.com/in/banurohit-vutukuri/)
**Email:** vutukuribanurohit02@gmail.com

---

I build digital hardware from the register level down to the bitstream — writing SystemVerilog RTL, proving correctness with self-checking testbenches and formal methods, and validating every design on real FPGA hardware before calling it done.

This repo tracks that process end-to-end: **spec → RTL → simulation → synthesis → silicon.** Each project below is built independently, verified rigorously, and — where possible — pushed all the way to physical hardware, not left as a simulation-only exercise.

---

## Toolchain

| Category | Tools |
|---|---|
| RTL | SystemVerilog |
| Synthesis / Implementation | Vivado ML Standard Edition (Xilinx Artix-7) |
| Simulation | Vivado Simulator (XSim), Icarus Verilog, Verilator |
| Formal Verification | SymbiYosys |
| ASIC Flow | Yosys, OpenLane, OpenROAD, KLayout |
| Hardware | Digilent Nexys A7 (AMD Artix-7 XC7A100T) |

---

## Projects

### ✅ Project 1 — UART / APB Peripheral

A configurable UART transmitter/receiver wrapped in an AMBA APB register interface — the first building block toward a full SoC.

- **Register map:** `0x00` TXDATA · `0x04` RXDATA · `0x08` STATUS · `0x0C` BAUDDIV, implemented as a clean APB slave
- **Design:** 16× oversampled baud rate generator, FSM-based TX and RX shift registers, 2-flop synchronization on the RX input to guard against metastability
- **Verification:** Self-checking SystemVerilog testbenches — **44/44 TX checks** and **4/4 RX checks passed** across four data patterns (0xA5, 0x00, 0xFF, 0x55)
- **Hardware validation:** Synthesized, implemented, and **programmed onto a real Nexys A7 (Artix-7 XC7A100T)** via a board-level wrapper (`nexys_uart_top.sv`) driven by switches and LEDs for a live APB read/write demo
- **Status:** RTL complete, formally simulated, synthesized, and running on real hardware.

**[→ Full technical write-up and verification details](./project1-uart/README.md)**

### ✅ Project 2 — Async FIFO with Formal CDC Proof

*Complete — core safety property formally proven, functional simulation passing*

A clock-domain-crossing FIFO with correctness proven formally via SymbiYosys, not only simulated — the verification depth most student portfolios skip.

**[→ Full technical write-up and verification details](./project2-async-fifo/README.md)**

### ✅ Project 3 — RV32I ALU

*Complete*

A formally verified RV32I arithmetic logic unit — every one of 11 correctness properties proven exhaustively, not just simulated.

- **Design:** 10 RV32I ALU operations (ADD, SUB, AND, OR, XOR, SLT, SLTU, SLL, SRL, SRA) plus a zero flag, driven by a clean 4-bit opcode
- **Verification:** Self-checking functional testbench — **527/527 checks passed**; formal proof via SymbiYosys/Boolector — **11/11 properties proven**, exhaustively covering every opcode and operand combination
- **Debugging highlight:** Caught and resolved a false counterexample on the SRA property — traced to a Boolector SMT-translation quirk on variable-shift-amount arithmetic right shift, confirmed correct via netlist inspection and hand computation, fixed with a sign-extend/logical-shift/truncate reformulation
- **Status:** RTL complete, functionally simulated, formally proven, fully documented

**[→ Full technical write-up and verification details](./project3-rv32i-alu/README.md)**

### ⚪ Project 4 — Single-Cycle RV32I CPU

*Planned*

A single-cycle RV32I processor capable of running compiled C — the flagship project tying every earlier piece together.

---

## Stretch Goals

- **Research paper reimplementation** — applying the methodology from Weingarten, Datta, Kole & Drechsler, *"Complete and Efficient Verification for a RISC-V Processor Using Formal Verification,"* DATE 2024, to a self-built RV32I core: extending formal proofs beyond the ALU into full sequential correctness.
- **Tiny Tapeout silicon submission** — fabricating a compact verified module on the SkyWater SKY130 process via the TTSKY26c shuttle.

---

## Contact

**Banu Rohit Vutukuri**
[LinkedIn](https://www.linkedin.com/in/banurohit-vutukuri/) · [vutukuribanurohit02@gmail.com](mailto:vutukuribanurohit02@gmail.com)
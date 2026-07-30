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

### ✅ Project 4 — Single-Cycle RV32I CPU

*Complete*

A single-cycle RV32I CPU integrating the formally-verified ALU, register file, decoder, and control unit — proven not just in simulation, but by compiling and running a real C program on it.

- **Design:** Full RV32I datapath (PC logic, branch/jump resolution, unified Von Neumann memory) wired from Project 3's ALU plus new register file, decoder, and control modules
- **Real C running on real hardware logic:** Built a bare-metal RISC-V GCC cross-toolchain from source and compiled a bubble-sort program; ran the compiled binary on the CPU in simulation — array correctly sorted end to end
- **Formal verification:** Control-unit ALU-op selection, branch/next-PC logic, and the x0-hardwired-to-zero invariant proven against independent reference computations — including catching and fixing two vacuous proofs before trusting the results
- **Debugging highlight:** Traced a nested-loop sort exiting on its first iteration down to a single 4-bit ALU op-encoding mismatch, via cycle-by-cycle waveform analysis
- **Status:** RTL complete, functionally simulated running real compiled C, formally verified, fully documented

**[→ Full technical write-up and verification details](./project4-rv32i-cpu/README.md)**

---

### ✅ Project 5 — RTL-to-GDSII Physical Design

- **What it is:** the Project 3 RV32I ALU hardened to a manufacturable layout on the SkyWater sky130 open PDK, using LibreLane (OpenLane 2) and OpenROAD
- **Sign-off:** nine-corner static timing analysis clean at a 33 ns period; **zero DRC, LVS, and antenna violations**
- **Results:** 1,293 standard cells, 21,303 µm² core area, 31.5–56.3 MHz across PVT corners
- **Debugging highlight:** investigated 208 timing-repair buffers and confirmed via a clock-period sweep that they serve max-slew/max-cap electrical rules rather than setup timing — the buffer count was invariant to the constraint
- **Status:** hardened, signed off, documented
- [Write-up](https://vutukuribanurohit02.github.io/fpga-portfolio/project5-physical-design/) · [Source](https://github.com/Vutukuribanurohit02/fpga-portfolio/tree/main/project5-physical-design)

### 🔁 Project 6 — Polynomial Formal Verification (research reimplementation)

- **What it is:** a reimplementation of the per-instruction BDD equivalence-checking methodology from Weingarten et al. (DATE 2024) and PolyMiR (NANOARCH 2023), retargeted to my RV32I ALU. Their toolchain (PSIM, SYMSIM, RMG) was never released, so the flow was reconstructed from the published method description using Yosys, py-aiger, and dd.
- **Method:** opcode pinning → Yosys constant propagation to extract the per-instruction sub-circuit → AIG → ROBDD under a controlled variable order → node counting against the paper's published Table III
- **Results:** AND = **97** and XOR = **161**, matching the published counts exactly. ADD measured 1553 against their 1327, but per-output-bit growth is exactly linear with closed form `3k + 2`, independently confirming the paper's Θ(n²) Addition-group bound.
- **Methodological finding:** BDD node counts are unreproducible without a stated variable ordering. Unpinned hash seeds produced 6036 vs 6585 nodes across runs, and a grouped ordering exhausted 7 GB and failed to terminate on the same circuit that builds in 0.5 s interleaved.
- **Status:** extraction and BDD construction working on 3 of 10 opcodes; reference-model generation (and therefore the equivalence check itself) not yet built
- [Details](project6-pfv/README.md) · [Concepts primer](project6-pfv/CONCEPTS.md) · [Source](https://github.com/Vutukuribanurohit02/fpga-portfolio/tree/main/project6-pfv)

## Stretch Goals

- **Tiny Tapeout silicon submission** — fabricating a compact verified module on the SkyWater SKY130 process via the TTSKY26c shuttle.

---

## Contact

**Banu Rohit Vutukuri**
[LinkedIn](https://www.linkedin.com/in/banurohit-vutukuri/) · [vutukuribanurohit02@gmail.com](mailto:vutukuribanurohit02@gmail.com)
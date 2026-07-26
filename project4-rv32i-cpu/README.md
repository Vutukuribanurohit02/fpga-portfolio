# Project 4 — Single-Cycle RV32I CPU

*Complete*

A single-cycle RV32I processor built from scratch, integrating a formally-verified ALU (Project 3), a register file, an instruction decoder, and a control unit into a working datapath — then proving it by compiling real C with a self-built GCC cross-toolchain and running the compiled binary on the CPU in simulation.

**[→ Project 3 (RV32I ALU, reused here)](../project3-rv32i-alu)**

## Architecture

- **Style:** Single-cycle, non-pipelined
- **Memory:** Unified (Von Neumann) — one 8KB byte-addressable array shared by instruction fetch and data load/store
- **ISA coverage:** Full RV32I base integer instruction set — R-type, I-type, S-type, B-type, U-type, J-type

### Modules

| Module | Role |
|---|---|
| `rtl/alu.sv` | 10 ALU operations (reused from Project 3, formally verified there) |
| `rtl/regfile.sv` | 32×32-bit register file, x0 hardwired to zero |
| `rtl/decoder.sv` | Instruction field split + immediate generation for all 6 formats |
| `rtl/control.sv` | Opcode/funct3/funct7 → datapath control signals |
| `rtl/mem.sv` | Unified byte-addressable memory, LB/LH/LW/LBU/LHU + SB/SH/SW |
| `rtl/rv32i_cpu.sv` | Top-level datapath: PC logic, branch/jump resolution, module wiring |

## Running Compiled C

A bare-metal RISC-V GCC cross-toolchain (`riscv32-unknown-elf-gcc`, built from source, targeting plain `rv32i`/`ilp32`) compiles a real C program that the CPU executes in simulation — not hand-written test instructions.

**Test program:** bubble sort on an 8-element array (`sw/bubble_sort.c`), chosen to exercise the full instruction set together — loops, branches (BLT/BGE), array indexing, loads/stores, and function calls — rather than isolated operations.
A hand-written startup stub (`sw/start.s`) initializes the stack pointer before `main()` runs, since GCC-generated code always assumes this has already happened — there is no OS or crt0 doing it automatically on bare metal.

## Verification

### Functional simulation
Self-checking Icarus Verilog testbench (`sim/rv32i_cpu_tb.sv`) loads the compiled program via `$readmemh`, runs the CPU for 3000 cycles, and checks the sorted array directly in memory.

### Formal verification
Full-CPU model checking is intractable for a single-cycle RV32I core (state space is enormous — 32×32-bit registers plus memory). Instead, three targeted properties are proven exhaustively across their full input space:

| Property | Module | Result |
|---|---|---|
| ALU-op selection is correct for every opcode/funct3/funct7 encoding (R-type, I-type, branches) | `control.sv` | ✅ Proven (BMC depth 2) |
| `branch_taken` and `pc_next` are correct for every jump/jalr/branch/fall-through case | `rv32i_cpu.sv` | ✅ Proven (BMC depth 2) |
| x0 always reads zero, regardless of write-enable or address | `regfile.sv` | ✅ Proven (BMC depth 5) |

Each property is checked against an **independently-written reference computation**, not derived from the RTL's own case statements — this is what makes the proof meaningful rather than circular.

Every proof was re-run in `cover` mode to confirm the underlying conditions are actually reachable, after two proofs in this project turned out to be silently vacuous (see below) despite reporting "PASS."

## The Debugging Story

Getting from "elaborates cleanly" to "runs real compiled C correctly" surfaced five distinct bugs, found through progressively narrower cycle-by-cycle waveform tracing rather than guessing:

1. **Toolchain build OOM** — `riscv-gnu-toolchain`'s parallel build (`-j$(nproc)`) exceeded WSL's available RAM building `gimple-match-3.o`. Fixed by reducing parallelism to `-j4`.

2. **`_start` not at address 0** — the linker placed `bubble_sort()` before `_start()` in `.text` because GCC doesn't separate functions into distinct sections by default. Fixed by forcing `_start` into its own linker-recognized section.

3. **Uninitialized stack pointer** — with `sp` never set, the compiled program's first instructions computed a stack address far outside the 8KB memory array, corrupting every subsequent load/store. Fixed with a hand-written `start.s` that initializes `sp` before calling `main()` — the same job a real bootloader/crt0 does on hardware.

4. **Combinational loop in the register file** — an unnecessary same-cycle write-bypass (`rs1_data → rd_data → alu_result → rs1_data`) hung the Icarus simulator indefinitely on the very first `addi sp,sp,-16` instruction, since `rd == rs1` there. Diagnosed by realizing a single-cycle CPU never needs same-cycle bypass in the first place — each instruction's write commits at the clock edge and is naturally visible to the next instruction's read.

5. **ALU op-encoding mismatch** — `control.sv` assumed an ALU opcode ordering that didn't match Project 3's actual `alu.sv` encoding. Every branch requiring SLT/SLTU (BLT/BGE/BLTU/BGEU) silently executed SLL instead, causing the outer sort loop to exit on its first iteration. Found by tracing `pc`/`rs1`/`rs2`/`alu_result`/`branch_taken` cycle-by-cycle down to the exact failing instruction, then cross-referencing the real op table.

**Two vacuous formal proofs, also caught and fixed:** the first `pc_bind.sv` attempt used SystemVerilog's `bind` construct, and Yosys's `prep` pass silently removed the entire properties module as "unused" — the proof reported PASS having checked nothing. The second attempt used a dot-path (`dut.funct3`) reaching across module scopes, which Yosys silently converted to a floating undriven wire rather than erroring — same failure mode as the async FIFO bug from Project 2. Both were caught by explicitly running `cover` mode and confirming zero cover statements were reported reachable, rather than trusting a "PASS" result at face value. The fix in both cases: expose internal signals as real ports with same-scope `assign` statements, never reach across module boundaries with raw hierarchical references.

## Toolchain

| Category | Tool |
|---|---|
| RTL | SystemVerilog |
| Simulation | Icarus Verilog |
| Formal Verification | SymbiYosys / Yosys / Boolector |
| C Cross-Compiler | riscv-gnu-toolchain (rv32i/ilp32, built from source) |

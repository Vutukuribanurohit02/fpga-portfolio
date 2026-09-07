# Project 04 — RV32I CPU running compiled C

**One line:** three verified blocks assembled into a single-cycle processor that runs a compiled C program — and that riscv-formal proved conformant to the ISA after finding a real bug in it.

---

## What it is

A single-cycle RV32I CPU with unified (Von Neumann) memory, integrating the formally verified ALU from Project 3, a register file, a decoder and a control unit.

### Module structure

| File | Role |
|---|---|
| `rv32i_soc.sv` | Top level: CPU + memory |
| `rv32i_cpu.sv` | The core — PC, decode, execute, writeback, memory interface |
| `rv32i_alu.sv` | The ALU from Project 3, unmodified |
| `regfile.sv` | 32×32 register file, x0 hardwired to zero |
| `decoder.sv` | Instruction field extraction and immediate reconstruction |
| `control.sv` | Opcode/funct3/funct7 → control signals |
| `mem.sv` | Unified byte-addressable memory with a word bus |

---

## Design decisions and why

**Single-cycle.** One instruction retires per clock. The whole datapath is combinational within a cycle; only the PC and register file are sequential.

The cost is speed — the critical path is the entire datapath, so maximum frequency is low. The benefit is verification: no pipeline means no hazards, no forwarding, no stalls, and no ambiguity about which instruction is retiring when. That is what made adding RVFI nearly trivial. On a pipelined core, tracking values down to writeback and getting `rvfi_order` right is where most of the work would be.

**Memory lifted out of the core.** Originally `mem` was instantiated *inside* `rv32i_cpu`, so the core's only ports were `clk` and `rst_n`. That caused two problems for formal verification: the 8 KB array is 65,536 bits of state the solver must reason about, and there was no memory interface at the module boundary to drive freely.

The refactor created `rv32i_soc.sv` as a new top instantiating CPU + memory, with the core exposing instruction and data buses at its ports. Formal then drives those as free inputs and the array disappears from the proof entirely. Cleaner architecturally *and* verification-enabling.

**Load extension moved into the CPU.** `mem.sv` originally sign- and zero-extended load data internally per `funct3`. That is architecturally wrong — sign extension is a property of the *load instruction*, not of the memory — and it meant RVFI had no real bus word to report.

Memory now presents a plain word bus: aligned address, raw 32-bit read data, 4-bit write strobes. Byte selection and extension live in the CPU writeback path. The result is that every RVFI memory field is a real wire rather than a reconstruction.

**One core, not two.** An `rv32i_cpu_formal.sv` duplicate existed carrying debug ports for the bind-file proofs. Two copies of a core is a divergence hazard — a proof against one says nothing about the other once they drift. Merged into a single file with the debug ports behind `` `ifdef FORMAL ``.

---

## Verification, in three layers

### Layer 1 — running real software

A bare-metal **RISC-V GCC cross-toolchain built from source** (not installed from a package manager), targeting this core. A compiled C bubble-sort runs end to end from reset through completion with correct results.

That closes the loop from "the RTL simulates correctly" to "this is a computer that runs software written without knowledge of it."

### Layer 2 — block-level formal proofs

SymbiYosys proofs on the control unit, the register file, and the PC / branch logic, with bind files keeping assertions out of synthesisable RTL. Two vacuous proofs were caught and fixed here, applying the Project 2 lesson directly.

**But be precise about what the PC proof proves.** `pc_bind.sv` compares `branch_taken` against an `expected_branch_taken` computed *in the bind file, from the same ALU result, with the same case statement*. It catches typos and refactor damage. It cannot catch a misreading of the specification, because both sides would be wrong identically. Calling it an "independent reference computation" was generous.

### Layer 3 — riscv-formal ISA conformance

The core was instrumented with an **RVFI trace port** reporting, every cycle: the retired instruction word, both source registers and values, the destination write, PC before and after, the full memory transaction, and a trap flag.

The harness instantiates the CPU with **no memory attached** — `instr_data` and `data_rdata` are free inputs, so the solver explores every response memory could give.

**Result: 43 of 43 checks pass** — 37 per-instruction, plus register-file consistency, PC forward and backward, causality, uniqueness, and cover.

---

## The bug riscv-formal found

First run: **14 of 43 failed**, all on the same assertion — `assert(spec_trap == trap)`.

RV32I requires a trap when a branch or jump computes a misaligned target, and on misaligned half/word memory access. **The core had no trap support whatsoever.**

Adding trap detection fixed the loads, stores and jumps. **Every branch still failed.**

The counterexample, read from the trace: a PC that was *already* misaligned, executing a branch that was *not taken*. The next PC is `pc + 4`, which inherits the misalignment — and the specification raises the trap based on the branch's computed target **whether or not the branch is taken**.

The condition was gated on `branch_taken`. It needed to be gated on `branch`. One word.

### Why nothing else could have found it

- **No directed test would construct that state.** It requires arriving at a misaligned PC and then executing a non-taken branch there.
- **The bubble sort never hits it.** Real compiled code doesn't run from misaligned addresses.
- **The bind-file proof structurally cannot see it,** because it re-derives the branch condition from the same signals.

Only a check against the specification itself could catch it. That contrast is the whole argument for ISA-level formal verification.

---

## What the debugging cost, and what that taught

Getting from 14 failures to zero took six wrong hypotheses and two broken measurement methods.

Debug signals tapped through hierarchical dot-paths from the wrapper into the flattened design reported **zero at every timestep** — no Yosys warning. Two full sessions were spent reasoning about a core that appeared idle and was running perfectly. A signal pair that was arithmetically impossible (`pc = 0` and `pc_plus4 = 0` simultaneously, when `pc_plus4` is a continuous assign of `pc + 4`) was the tell.

**The fix was the pattern this project's own bind file already used:** observe through real module ports, guarded by `` `ifdef ``, never through dot-paths into a flattened design.

One more subtlety worth keeping: the `cover` check failed until its condition changed from `cnt_insns == 2` to `>= 2`. The reference configuration is written for cores that stall between retirements; a single-cycle core increments past 2 before the bounded check samples it.

---

## Scope, stated plainly

- Proofs run under `RISCV_FORMAL_ALIGNED_MEM`, the same assumption the reference picorv32 configuration uses — misaligned access is assumed away at the bus level.
- No CSRs, no interrupts, no compressed instructions. Base RV32I only.
- Single-cycle, so no pipeline hazards exist to verify.

---

## Questions you should be able to answer

1. Why did lifting memory out of the core make the formal proof tractable?
2. What is the difference between `pc_bind.sv`'s proof and riscv-formal's, in one sentence?
3. Why does the spec trap on a *not-taken* branch's target?
4. Why does driving memory as a free input give stronger results than attaching a real memory?
5. Why is sign extension the CPU's job rather than the memory's?
6. What made the debug taps report zeros with no warning, and what is the general defence?
7. Why is `rvfi_valid` combinational here, and what would break on a pipelined core?

## Where it leads

Project 5 takes the same verified RTL and turns it into physical silicon.

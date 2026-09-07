# Fundamentals

The concepts every project in this portfolio rests on, explained properly, using the portfolio's own work as the examples. Read this first if a term in a project document is unfamiliar.

---

## 1. Simulation versus formal verification

**Simulation** runs the design with specific inputs and checks specific outputs. A testbench that runs 120 random vectors has checked 120 points in an input space of 2^64 per opcode. It found no bug, which is not the same as there being no bug.

**Formal verification** asks a solver to prove a property holds for *every* input, or to produce a counterexample. It doesn't sample — it searches the state space symbolically.

The trade is coverage against cost. Simulation scales to enormous designs and tells you nothing about the states it didn't visit. Formal gives exhaustive answers about small designs and can blow up unpredictably on large ones.

Both appear throughout this portfolio, and the interesting results come from the places where they disagree:

- Project 4's CPU ran a compiled C bubble-sort correctly, end to end. It still had a specification bug that formal found in seconds.
- Project 6 exists specifically to study *when* formal verification's cost is predictable.

### Bounded model checking (BMC)

The specific formal technique used in Projects 2, 3, 4 and 6. The solver unrolls the design for N clock cycles and asks: is there any input sequence, starting from a legal reset state, that violates the property within N cycles?

If no — the property holds *up to depth N*. That bound matters. A bug that takes 25 cycles to manifest is invisible to a depth-20 proof. When a document says "proven to depth 20," that qualifier is doing real work.

If yes — the solver hands back a **counterexample trace**: the exact input sequence that breaks it. This is the single most valuable output of formal verification. It's not a report that something is wrong; it's a minimal recipe for reproducing it.

### Vacuity — the failure mode that matters most

A proof can pass because the property is true, or because the property was never actually connected to the design. The second is a **vacuous proof**, and it is worse than no proof: it manufactures confidence.

This portfolio has hit vacuity three times, in three different disguises:

1. **Project 2** — unresolved hierarchical signal references meant the solver checked a property structurally disconnected from the FIFO. It passed. It was checking nothing.
2. **Project 4** — two more vacuous proofs caught during the CPU's block-level formal work, found because Project 2 had made auditing every PASS a standing step.
3. **Project 4, again, during riscv-formal debugging** — debug signals tapped through hierarchical dot-paths into a flattened design reported zero at every timestep. Yosys emitted no warning. Two full debugging sessions were spent reasoning about a core that appeared idle and was actually running perfectly.

The recurring cause is the same: **hierarchical dot-paths into a design that has been flattened**. After `prep -flatten`, those references can resolve to constants rather than to live nets.

The defence is structural, not vigilant: **observe through real module ports**, guarded by `` `ifdef `` if they shouldn't exist in synthesis. A port cannot silently disconnect. Project 4's `pc_bind.sv` header comment says exactly this — and the lesson still had to be relearned when the same mistake was made from the wrapper side.

**Cover statements are the standard anti-vacuity tool.** A `cover` asks the solver to *reach* a state rather than avoid one. If your assertions pass but your cover points are unreachable, your proofs are probably vacuous — the design can't get anywhere interesting, so nothing is being constrained.

### Proving against yourself versus proving against the spec

This distinction is the intellectual centre of the portfolio.

Project 4's `pc_bind.sv` proves `branch_taken` matches an `expected_branch_taken` computed *in the bind file* — from the same ALU result, with the same `case` statement. That catches typos and refactor damage. It **cannot** catch a misreading of the RISC-V specification, because both sides would be wrong in the same way.

`riscv-formal` compares against an independent model of the ISA itself. It found a real trap-condition bug that the bind-file proof passed over for months.

When you write or read "formally verified," always ask: *verified against what?*

---

## 2. Clock domain crossing (CDC)

Two clocks that aren't derived from a common source are **asynchronous** — their edges drift relative to each other with no fixed relationship. Project 2 runs a 100 MHz write domain against a 66 MHz read domain.

### Metastability

A flip-flop has a **setup** window before the clock edge and a **hold** window after it during which its data input must be stable. Violate that window and the flop can enter a metastable state: output neither 0 nor 1, resolving unpredictably after an unbounded time.

You cannot prevent this when sampling a genuinely asynchronous signal. You can only make the probability of it propagating vanishingly small.

**The 2-flop synchronizer** is the standard defence: two flops in series in the receiving domain. The first may go metastable; it is given a full clock period to settle before the second samples it. This doesn't eliminate failure, it pushes the mean time between failures out to years or centuries. Project 1 uses one on the incoming serial line — an external asynchronous input — and Project 2 uses them on every signal crossing domains.

### Gray code, and why binary pointers are unsafe

A FIFO must compare write and read pointers across the clock boundary to compute full and empty. But a multi-bit binary counter incrementing from `0111` to `1000` changes four bits. The receiving domain, sampling mid-transition, can observe *any* combination of old and new bits — including values the counter never held.

**Gray code** guarantees exactly one bit changes per increment. Sampling mid-transition therefore yields either the old value or the new value, never a fictional third. That property is what makes 2-flop synchronizing a multi-bit pointer sound.

This is the Cummings SNUG 2002 architecture, which nearly every production async FIFO traces back to, and it is what Project 2 implements.

---

## 3. Static timing analysis (STA)

Simulation tells you the design computes the right values. STA tells you whether it computes them *in time*. These are independent questions and a design can pass one while failing the other.

### Setup and hold

Every path from one flop to another has a propagation delay.

- **Setup**: the data must arrive *before* the next clock edge, with margin. Fails when logic is too slow or the clock is too fast. Fixed by shortening the path or lengthening the clock period.
- **Hold**: the data must *not* arrive too early and overwrite the value the receiving flop is still capturing from the previous edge. Fails when a path is too short relative to clock skew. Fixed by inserting delay.

**Slack** is the margin: positive means the constraint is met, negative means violated. Project 7's final sign-off has setup slack +0.425 ns and hold slack +0.117 ns — both positive, both thin.

Setup is a *speed* problem you can fix by slowing the clock. **Hold is a fix-it-or-it's-broken problem** — it doesn't go away at any clock frequency, because it's about relative arrival times, not the period.

### Clock trees and skew

The clock must reach thousands of flip-flops. Real wires have delay, so the clock arrives at different flops at slightly different times. That difference is **skew**.

A **clock tree** is a buffer network inserted during physical design to distribute the clock with controlled skew. Project 7's hardened design has 117 clock buffers and 0.255 ns of skew — up from zero in Project 5's purely combinational version, which had no clock tree at all because it had no sequential elements to clock.

Skew is not purely harmful (deliberate skew can borrow time), but uncontrolled skew eats directly into both setup and hold margin.

### PVT corners

Silicon behaves differently depending on **P**rocess (manufacturing variation), **V**oltage, and **T**emperature. A chip that meets timing in a typical corner may fail in a slow-process, low-voltage, high-temperature corner.

**Sign-off** means checking every corner that matters. Project 5 characterised across nine PVT corners and measured 31.5 MHz worst-case against 56.3 MHz best-case — a **1.8× spread on identical silicon**. That number is the concrete answer to "why can't you just quote one frequency?"

---

## 4. The RTL-to-GDSII flow

How a hardware description becomes a manufacturable layout. Project 5 does this with a free floorplan; Project 7 does it again on a fixed die.

1. **Synthesis** — RTL is mapped to standard cells from the PDK's library. Output is a gate-level netlist.
2. **Floorplanning** — the die area, core area and pin placement are decided. On Tiny Tapeout this is fixed for you, which is precisely what makes it a different problem.
3. **Placement** — every standard cell gets physical coordinates.
4. **Clock tree synthesis (CTS)** — the clock distribution network is built and buffered.
5. **Routing** — the metal layers connecting everything are laid down.
6. **RC extraction** — actual resistance and capacitance are extracted from the routed geometry, giving real delays instead of estimates.
7. **Sign-off STA** — timing re-checked against extracted parasitics, across corners.
8. **Physical verification** — DRC, LVS, antenna.

### DRC, LVS and antenna

- **DRC** (Design Rule Check): does the layout obey the foundry's geometric rules — minimum widths, spacings, enclosures? A DRC violation means the fab may not be able to manufacture it correctly.
- **LVS** (Layout Versus Schematic): does the layout's extracted netlist match the netlist you intended? Catches routing that connected the wrong things.
- **Antenna**: during manufacture, long metal segments can accumulate charge and destroy thin gate oxide before the connecting layers exist. Antenna rules bound this.

Zero of all three is the minimum bar for a tapeout. Projects 5 and 7 both achieve it.

### Gate-level simulation

After routing, the netlist is re-simulated with the same tests that passed at RTL. This is the check that **what got laid out still does what the RTL did** — that synthesis and place-and-route didn't change behaviour. Project 7 runs all ten cocotb tests at both RTL and post-route gate level.

### Utilisation

The fraction of core area occupied by standard cells. Project 7 runs at 85.5% — high, which is efficient but leaves the router less room. Note from Project 7 that relaxing the clock constraint from 20 ns to 25 ns *dropped* utilisation from 85.2% to 80.4%: with more timing margin, synthesis chose smaller, slower cells.

---

## 5. RISC-V and the RV32I base

**RV32I** is the 32-bit base integer instruction set: arithmetic, logic, shifts, comparisons, loads, stores, branches, jumps. No multiply, no floating point, no compressed instructions, no CSRs. Roughly 40 instructions.

It is deliberately minimal, which is what makes it a realistic target for a portfolio CPU.

### Single-cycle execution

Project 4's CPU retires one instruction per clock cycle. Fetch, decode, execute, memory and writeback all happen combinationally within one cycle, and only the PC and register file are sequential.

The consequence: **the critical path is the entire datapath**, so maximum frequency is low. The benefit for verification is large — there is no pipeline, so no hazards, no forwarding, no stalls, and no ambiguity about which instruction is retiring when. That is what made adding RVFI nearly free.

### Von Neumann versus Harvard

Project 4 uses a **unified memory**: instructions and data share one array. Simple, and realistic for a small system. It caused a specific problem for formal verification — with memory *inside* the CPU module, the 8 KB array became 65,536 bits of state the solver had to reason about, and there was no memory interface at the module boundary to drive freely.

The fix was to lift memory out into an SoC wrapper, so the core exposes instruction and data buses at its ports. Formal then drives those as free inputs and the array disappears from the proof entirely. This is a good example of a change that is *architecturally cleaner* and *verification-enabling* at the same time.

### Misaligned access and traps

RV32I requires that a word load be word-aligned and a halfword load be halfword-aligned; misaligned access raises a trap. Similarly, a branch or jump to a target that isn't 4-byte aligned raises an instruction-address-misaligned trap.

Project 4 originally had no trap support at all. `riscv-formal` found this immediately. The subtle part, and the bug that took longest to find:

> The specification raises the misaligned-target trap based on the branch's **computed** next PC, **whether or not the branch is taken**. A not-taken branch's `pc + 4` inherits misalignment from an already-misaligned PC.

Gating the trap on `branch_taken` therefore missed the case. Gating on `branch` is correct.

---

## 6. RVFI — the RISC-V Formal Interface

A standard trace port for RISC-V cores. Every cycle, the core reports what retired:

| Signal | Meaning |
|---|---|
| `rvfi_valid` | An instruction retired this cycle |
| `rvfi_order` | Monotonic retirement counter |
| `rvfi_insn` | The instruction word |
| `rvfi_rs1_addr` / `rs2_addr` + `rdata` | Source registers and their values |
| `rvfi_rd_addr` / `rd_wdata` | Destination register write |
| `rvfi_pc_rdata` / `pc_wdata` | PC before and after |
| `rvfi_mem_addr` / `rmask` / `wmask` / `rdata` / `wdata` | Memory transaction |
| `rvfi_trap` | This instruction raised a trap |

`riscv-formal` consumes this port and compares each retirement against a per-instruction model of the ISA. Because the harness attaches **no memory** — instruction and data words are free inputs — the solver explores every memory response the core could ever see, not the handful a testbench provides.

**Every field must describe the same instruction.** Mixing registered and combinational fields introduces a one-cycle skew that is invisible for straight-line code (instruction N's `pc_wdata` equals instruction N+1's `pc_rdata` either way) and breaks immediately on branches.

---

## 7. Tools

| Tool | Role | Used in |
|---|---|---|
| **Icarus Verilog** | RTL simulation | 1, 2, 3, 4 |
| **cocotb** | Python-based testbenches | 7 |
| **Yosys** | Open-source synthesis and netlist manipulation | 2–7 |
| **SymbiYosys (sby)** | Formal verification driver | 2, 3, 4, 6 |
| **Boolector** | SMT solver behind the BMC | 2, 3, 4 |
| **riscv-formal** | ISA conformance framework | 4 |
| **LibreLane / OpenROAD** | RTL-to-GDSII physical implementation | 5, 7 |
| **OpenSTA** | Static timing analysis | 5, 7 |
| **sky130 PDK** | SkyWater 130 nm open process design kit | 5, 7 |
| **Vivado** | FPGA synthesis and implementation | 1 |
| **RISC-V GCC** | Cross-compiler, built from source | 4 |
| **BDD tooling** | Binary decision diagram equivalence checking | 6 |

### A note on reading tool output

Project 7's most valuable finding came from **not trusting a green checkmark**. The Tiny Tapeout CI reported a successful build that carried a −2.19 ns setup violation, because the workflow doesn't fail on timing. It was found by parsing `metrics.csv` out of the build artifact rather than reading the summary page.

The general lesson: know what your CI actually checks, and go read the numbers.

---

## 8. Glossary

**Assertion** — a property the solver must prove always holds.
**Assumption** — a constraint on inputs; narrows what the solver may explore. Over-constraining causes false passes.
**BDD** — Binary Decision Diagram; a canonical representation of a Boolean function. Size depends dramatically on variable ordering (Project 6).
**Bind file** — a formal-only module that instantiates the design and carries the properties, keeping assertions out of synthesisable RTL.
**Cover** — asks the solver to *reach* a state; the standard vacuity check.
**Critical path** — the slowest timing path; sets maximum frequency.
**Netlist** — a design expressed as interconnected gates or cells rather than behaviour.
**PDK** — Process Design Kit; the foundry's cell libraries and rules.
**Shuttle** — a shared fabrication run splitting mask costs across many designs (Project 7).
**Slack** — timing margin; positive is met, negative is violated.
**Standard cell** — a pre-characterised logic gate from the PDK library.
**Wrapper** — a module adapting a design to an external interface, e.g. Tiny Tapeout's fixed 24-pin boundary.

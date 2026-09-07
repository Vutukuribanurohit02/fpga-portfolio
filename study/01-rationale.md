# Why these projects, in this order

A portfolio of seven unrelated projects says "I can follow tutorials." A portfolio where each project is a prerequisite for the next says something different. This document is the argument for the sequence.

---

## The through-line

Every project answers a question the previous one raised.

```
01 UART/APB      →  I can build a peripheral. But how do I know it's right?
02 Async FIFO    →  Formal proof. But my first proof was checking nothing.
03 RV32I ALU     →  Formal proof done properly, on a real datapath block.
04 RV32I CPU     →  That block inside a working CPU that runs compiled C.
                    And proven against the ISA, not against my own logic.
05 Physical      →  That same verified RTL, hardened to routed silicon.
06 PFV           →  Research: when is formal verification's cost predictable?
07 Tiny Tapeout  →  The same block, on a real wafer.
```

Two artefacts thread through the whole thing: **the ALU** (written in 03, integrated in 04, hardened in 05, taped out in 07, and the research subject of 06) and **the vacuity lesson** (learned in 02, applied in 04, relearned the hard way in 04 again).

That's the portfolio's actual claim. Not "I did seven things," but "I took one design from RTL to a fabricated die, and verified it correctly at every level — including catching myself verifying nothing, three times."

---

## Project by project

### 01 — UART / APB Peripheral

**Question it answers:** can you build a peripheral that a real bus master could talk to, and put it on real hardware?

**Why it's first.** A UART is the standard first serious RTL project because it forces protocol timing, oversampling, and FSM design without needing architectural knowledge. Wrapping it in an **AMBA APB** register interface is what raises it above a tutorial: a bare UART is a component, a UART behind a documented register map is a peripheral an SoC could actually integrate.

**What it establishes for later work.** The 2-flop synchronizer on the incoming serial line is the first appearance of metastability handling — a defence Project 2 then generalises into a full CDC architecture. And programming it onto a Nexys A7 establishes the pattern the portfolio repeats: **simulation passing is necessary, not sufficient.**

**Honest limitation.** Verification here is self-checking testbenches across chosen data patterns. Directed simulation. That limitation is the reason Project 2 exists.

---

### 02 — Asynchronous FIFO with Formal CDC Proof

**Question it answers:** how do you get confidence about a design where simulation is structurally inadequate?

**Why a FIFO, and why formal.** Clock-domain crossing bugs are among the most common causes of real silicon failures and among the hardest to catch by simulation — a CDC bug can survive thousands of cycles and still fail in the field, because simulation only walks the state space it happens to walk. This is the canonical case where "it passed the testbench" means very little.

The design is the **Cummings SNUG 2002** architecture: Gray-coded pointers, 2-flop synchronizers, genuinely independent 100 MHz and 66 MHz domains. Nearly every production async FIFO traces back to this paper, so implementing it is learning the reference solution rather than inventing a worse one.

**The result that matters isn't the proof.** It's that **the first proof passed and was wrong.** Unresolved hierarchical signal references meant the solver was checking a property structurally disconnected from the design — a vacuous proof, reporting success because it was checking nothing.

**Why that's the most valuable thing in the portfolio.** A vacuous proof is worse than no proof: it manufactures confidence. Catching one, and understanding *why* it happened, converts formal verification from a tool you run into a tool you can trust. Auditing every PASS became a standing step from here on — and it paid off twice more in Project 4.

---

### 03 — RV32I ALU, Formally Verified

**Question it answers:** can the technique from 02 be applied to a datapath block, exhaustively, across every operation?

**Why an ALU.** It is the natural next rung: purely combinational, so no CDC and no temporal reasoning, but wide enough that exhaustive simulation is impossible. Ten opcodes over two 32-bit operands is 2^64 input combinations per opcode. You cannot test that. You can prove it.

**Why it matters structurally.** This is the block that everything downstream reuses. It goes into the CPU in Project 4, gets hardened in Project 5, becomes the research subject in Project 6, and goes to a wafer in Project 7. Proving it correct *before* integrating it means every later failure can be attributed elsewhere — which is exactly what happened when riscv-formal found a bug in Project 4's branch logic and not in the ALU.

---

### 04 — RV32I CPU running compiled C

**Question it answers:** do verified blocks compose into a working processor?

**The integration claim.** Three independently verified pieces — ALU, register file, control unit — assembled into a single-cycle datapath. Integration is where designs break, because each block was verified against *its own* interface assumptions.

**The proof that counts.** A bare-metal **RISC-V GCC cross-toolchain built from source**, targeting this core, compiling a C bubble-sort that runs end to end from reset to completion with correct results. That closes the loop from "the RTL simulates correctly" to "this is a computer that runs software I didn't write for it."

**And then the result that reframes everything.** The CPU ran compiled C correctly. It passed block-level formal proofs. It still had a specification bug.

`riscv-formal` compares each retired instruction against a model of the ISA, with **no memory attached** — instruction and data words are free inputs, so the solver explores every response memory could give. On the first run, 14 of 43 checks failed, all on the same assertion: the core raised no traps at all. RV32I requires a trap on a misaligned branch or jump target, and on misaligned half/word memory access.

Adding trap detection fixed the loads, stores and jumps. Every branch still failed. The counterexample was a PC that was *already* misaligned, executing a branch that was *not taken* — where `pc + 4` inherits the misalignment, and the spec raises the trap regardless of whether the branch was taken. The condition was gated on `branch_taken`; it needed `branch`.

**Why this is the portfolio's strongest single argument.** No directed test would construct that state. And the existing block-level proof could not catch it, because `pc_bind.sv` re-derives the branch condition from the same signals with the same case statement — it proves the design consistent *with itself*. Only a check against the specification could find it.

Final state: **43 of 43 riscv-formal checks pass.**

---

### 05 — Physical Design: RTL to GDSII

**Question it answers:** what does the verified RTL become as physical silicon, and what does that cost?

**Why this rung exists.** Everything before this is behaviour. Physical design is where a design acquires area, delay, power and manufacturability. A portfolio that stops at RTL demonstrates half the discipline.

**The measurement that makes it real.** Nine-corner PVT sign-off produced **31.5 MHz worst-case against 56.3 MHz best-case — a 1.8× spread on identical silicon**. That single number is the concrete answer to why designers quote corners rather than a frequency, and it isn't something you can learn from a textbook figure.

Zero DRC, LVS and antenna violations; zero inferred latches confirmed by lint. Gate-level critical path traced with OpenSTA to a named next-iteration target: a carry-lookahead adder.

**Naming the next fix is part of the result.** "The critical path is the ripple-carry chain and the fix is carry-lookahead" demonstrates you read the timing report rather than just passing it.

---

### 06 — Polynomial Formal Verification (DATE 2024 reimplementation)

**Question it answers:** formal verification's cost is unpredictable — when isn't it?

**Why this is different from every other project.** This is research reimplementation, not design. It takes the per-instruction BDD equivalence-checking methodology from Weingarten et al. (DATE 2024), applies it to the portfolio's own RV32I ALU with entirely open-source tools, and tries to reproduce the published node counts.

**Why it's worth doing.** Formal methods stay out of routine flows because their time and space costs are unpredictable — the same technique finishes in milliseconds on one circuit and exhausts memory on a structurally similar one. **Polynomial Formal Verification** asks the narrower question of which circuit classes admit provably polynomial verification cost.

**What was actually produced.** All ten opcodes proven equivalent to an independently constructed reference model. Six published node counts reproduced. The O(n²) complexity bound re-derived from measurement rather than taken on faith. And **two of my own earlier explanations disproved** by the equivalence work — the paper itself is under-specified about its counting convention rather than wrong.

The variable-ordering result is the most instructive: interleaved ordering (`a0, b0, a1, b1, …`) succeeds, while grouped ordering (`a0…a31, b0…b31`) exhausts more than 7 GB and gets OOM-killed. Same function, same tool, same machine — the ordering alone is the difference between seconds and impossible.

**What this signals.** Reading a current conference paper, reimplementing it on your own hardware, reproducing most of it, and correcting part of it is research work. It's the entry on this list that points at a PhD rather than at a job.

---

### 07 — Tiny Tapeout: real silicon

**Question it answers:** what changes when the die is fixed and you can't probe the result?

**Why it isn't just "Project 5 again."** Project 5 hardened the ALU with a free floorplan. Tiny Tapeout gives every project the same fixed pinout — `ui_in[7:0]`, `uo_out[7:0]`, `uio[7:0]` — 24 pins total. The ALU needs 68 input bits and produces 33 output bits. **Four times oversubscribed on input alone.**

**The engineering decision.** A serialisation FSM is the obvious approach and was rejected: an FSM carries sequencing state, sequencing state can desynchronise, and on a die with no probe access there is no way to detect that from outside and no recovery short of a full reset.

What was built instead is a **byte-addressed register file**. Any byte, any order, rewritable. No protocol state to lose, and no illegal states — because no sequence is being tracked. Cost: 68 flip-flops, and with them a real clock tree and hold analysis, turning a combinational block into a sequential design.

**The controlled comparison.** The same RTL is now hardened twice under different constraints: combinational on a free floorplan (05) versus sequential on a fixed tile (07). Reg-to-reg slack goes from infinity to +10.49 ns; skew from zero to 0.255 ns. That is the tool telling you what a clock tree costs, measured rather than asserted.

**The finding that matters most.** The first hardened build passed DRC, LVS, antenna and every gate-level test. CI reported success. It also carried a **−2.19 ns setup violation**, because the shuttle's CI doesn't fail on timing. It was found by parsing `metrics.csv` out of the build artifact instead of reading the summary page.

Final sign-off: setup +0.425 ns, hold +0.117 ns, skew 0.255 ns, zero DRC/LVS/antenna, 10/10 tests at RTL and post-route gate level.

**Honest scope.** A 1×1 tile on a shared educational shuttle, not production silicon. An ALU behind a byte-wide register interface is slower than the CPU driving it — thirteen bus transactions per operation. It is not an accelerator and shouldn't be described as one. What it is: the same RTL taken from formal proof through a fixed-die tapeout flow with a real clock tree, one timing violation caught behind a passing CI run, and a design that returns as a physical part in May 2027.

---

## What the sequence demonstrates, in one paragraph

One arithmetic block, written once, formally proven against an independent model, integrated into a processor that runs compiled C, proven again against the ISA specification where a real bug was found that neither simulation nor self-referential proofs could see, hardened to routed silicon twice under different physical constraints with nine-corner sign-off, studied as the subject of a research reimplementation that corrected two of the original paper's claims, and submitted to a shuttle that returns it as a fabricated die. Along the way, three separate instances of formal verification appearing to succeed while checking nothing — each one caught, and each one changing how the next proof was written.

---

## What's still open

Stated plainly, because a portfolio that claims completeness invites someone to find the gap themselves.

- **The silicon correlation is not done.** The Tiny Tapeout die returns in May 2027. Running the existing 134 vectors against the physical part and correlating measured behaviour with simulation is the step that would close the loop from RTL to measured silicon — and it's the part almost no student portfolio has.
- **Project 5 and Project 7 aren't a clean controlled comparison yet.** Some of the difference between them is constraint-driven rather than design-driven. Re-running Project 5 at 25 ns on a fixed die would isolate the effect of the clock tree from the effect of the clock constraint.
- **Project 4's proofs run under `RISCV_FORMAL_ALIGNED_MEM`** — the same assumption the reference picorv32 configuration uses. Misaligned memory access is assumed away at the bus level rather than verified. No CSRs, no interrupts, no compressed instructions.
- **The `pc_bind.sv` proofs are self-referential** and should be described that way rather than as independent reference computations.
- **RVFI-DII is done.** Direct instruction injection on Verilator, differential testing against a spec-derived reference model, and a delta-debugging shrinker. 164,000 instructions clean — and the tester itself validated by planting a known bug in the reference, which exposed a real coverage gap: the generator produced zero negative operands across 6,000 instructions, so sign-sensitive operations were never actually distinguished.

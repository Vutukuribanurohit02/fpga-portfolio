# Project 03 — RV32I ALU, Formally Verified

**One line:** the arithmetic block every later project reuses, proven correct across all ten operations against an independent reference model.

---

## What it is

A 32-bit RISC-V ALU implementing the RV32I base operations:

| Encoding | Op | Encoding | Op |
|---|---|---|---|
| `0x0` | ADD | `0x5` | SLT |
| `0x1` | SUB | `0x6` | SLTU |
| `0x2` | AND | `0x7` | SLL |
| `0x3` | OR | `0x8` | SRL |
| `0x4` | XOR | `0x9` | SRA |

Plus a zero flag. Shift amount uses only `b[4:0]`, per the RV32I specification.

---

## Why an ALU, at this point in the ladder

It is the right next rung after the FIFO for two reasons.

**Combinational, so the temporal reasoning disappears.** No clock, no state, no CDC. The formal problem reduces to: for all inputs, does the output match the reference? That isolates the verification technique from the timing complexity Project 2 introduced.

**The input space is genuinely unsampleable.** Two 32-bit operands is 2^64 combinations *per opcode*. Exhaustive simulation is not slow — it is impossible. This is the case where formal verification isn't a nicer alternative to testing; it is the only option that answers the question.

---

## Design decisions and why

**Sign handling in the comparisons.** SLT and SLTU differ only in signedness, and they are where comparison logic usually breaks — operands that differ in their sign bit produce opposite answers under signed and unsigned interpretation. Both are separate opcodes precisely because the hardware must do different things.

**Arithmetic versus logical right shift.** SRL zero-fills; SRA sign-extends. A single shifter with a fill-bit select handles both, and the sign-extension case is the one worth a directed test at the boundary (`0x80000000 >> 31`).

**Shift amount truncation.** RV32I specifies that only the low five bits of the shift operand are used. Shifting by `0x20` is therefore a shift by zero, not a shift out. This is a specification detail that is easy to implement wrongly and produces an obviously wrong answer when you do.

---

## Verification

Formally proven equivalent to an independently constructed reference model across **all ten opcodes** using SymbiYosys.

The word *independently* is load-bearing, and here it holds: the reference is the operation's mathematical result, computed independently of the RTL rather than re-derived from it.

Worth contrasting with Project 04, where two of the three block-level proofs (`pc_bind.sv` and `control_bind.sv`) *do* re-derive the design's own logic with the same case statements, and were described as independent when they aren't. Only `regfile_bind.sv`, which asserts an invariant rather than recomputing a value, is genuinely independent there. Getting this right in Project 03 and drifting in Project 04 is itself the lesson.

This is a distinction Project 4 later confronts directly: its `pc_bind.sv` branch proof *does* re-derive the design's own logic, and that proof passed over a real bug for months.

---

## Why this block matters beyond itself

It is the artefact the rest of the portfolio is built on:

- **Project 4** integrates it into a working CPU
- **Project 5** hardens it from RTL to routed silicon
- **Project 6** makes it the subject of a research reimplementation
- **Project 7** wraps it for a shuttle and sends it to a wafer

Proving it correct *before* integration is what let later failures be attributed elsewhere with confidence. When riscv-formal found a bug in Project 4, the ALU was never a suspect.

---

## Questions you should be able to answer

1. Why is exhaustive simulation impossible here, with numbers?
2. What makes SLT and SLTU produce different answers, and for which operands?
3. What does RV32I say about shift amounts greater than 31, and why?
4. What would make a reference model *not* independent, and why does that matter?
5. SUB and the comparison operations can share hardware. What does that sharing cost or save?
6. Which operation sits on the critical path, and why? (Project 5 answers this with measurement.)

## Where it leads

Project 4 puts this block inside a processor — where being correct in isolation stops being sufficient.

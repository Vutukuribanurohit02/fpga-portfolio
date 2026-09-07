# Project 02 — Asynchronous FIFO with Formal CDC Proof

**One line:** a dual-clock FIFO whose no-overflow safety property is formally proven, and whose first proof was vacuous.

---

## What it is

A parameterized dual-clock asynchronous FIFO on the **Cummings SNUG 2002** architecture, with a formally proven no-overflow guarantee across the clock domain crossing.

- Independent **100 MHz write** and **66 MHz read** domains, genuinely asynchronous
- **Gray-coded** write and read pointers
- **2-flop synchronizers** on every signal crossing domains

---

## Why this project exists

Clock-domain crossing bugs are among the most common causes of real silicon failure and among the hardest to catch by simulation. A CDC bug can survive thousands of simulation cycles and still fail in the field, because simulation only samples the state space it happens to walk through.

Formal verification exhaustively checks every reachable state up to the proof depth. That is why this project pairs the RTL with a SymbiYosys/Boolector bounded model check rather than relying on testbenches.

---

## Design decisions and why

**Why Gray code for the pointers.** A binary counter going from `0111` to `1000` changes four bits at once. The receiving domain sampling mid-transition can observe any mixture of old and new bits — including values the counter never held. Gray code guarantees exactly one bit changes per increment, so a mid-transition sample yields either the old or the new value and nothing fictional. That property is what makes synchronizing a multi-bit pointer sound at all.

**Why 2-flop synchronizers.** Standard metastability defence. The first flop may go metastable; it gets a full clock period to resolve before the second samples. This doesn't eliminate failure — it pushes mean time between failures out to years.

**Why the Cummings architecture rather than something invented.** Nearly every production async FIFO traces back to this 2002 paper. Implementing the reference solution is learning the correct answer rather than an inferior one.

---

## Verification

**Formal:** the `no_overflow` safety property proven via SymbiYosys with the Boolector solver, bounded model checking to **depth 20**. The property holds across every reachable state the solver can explore that deep.

**Simulation, alongside:** a self-checking testbench exercising both domains independently — 121 writes, 121 reads, 0 mismatches across the full 100/66 MHz split.

Note the qualifier on the formal result: *to depth 20*. A bug requiring 25 cycles to manifest would be invisible. Stating the bound is part of stating the result honestly.

---

## The bug that mattered more than the proof

**The first proof attempt passed — and was wrong.**

Unresolved hierarchical signal references meant the solver was checking a property structurally disconnected from the real design. It reported success because it was checking nothing. A **vacuous proof**.

### Why this is the most important result in the portfolio

A vacuous proof is worse than no proof. No proof leaves you appropriately uncertain. A vacuous proof leaves you confidently wrong.

Fixing the hierarchical reference and re-running produced a proof that actually constrains the design. From this point on, **auditing every PASS for vacuity became a standing step** — and it caught two more vacuous proofs in Project 4's CPU work.

It also recurred in a third disguise: during Project 4's riscv-formal debugging, debug signals tapped through hierarchical dot-paths into a flattened design reported zero at every timestep with no tool warning. Two full debugging sessions were spent reasoning about a core that appeared idle and was running perfectly.

**The structural lesson:** hierarchical dot-paths into flattened designs are the recurring cause. Observe through real module ports instead. A port cannot silently disconnect.

---

## Questions you should be able to answer

1. Why can't you just compare binary pointers across the clock boundary?
2. What exactly does a 2-flop synchronizer guarantee, and what does it not?
3. Why is the FIFO depth a power of two here, and what does the extra pointer bit do?
4. What does "proven to depth 20" allow you to claim, and what does it not?
5. How would you detect that a formal proof is vacuous, without being told?
6. Full and empty are computed in different clock domains. Why is that safe, and which one is allowed to be pessimistic?

## Where it leads

Project 3 applies formal verification to a combinational datapath block, where the input space is too large to sample but the temporal reasoning disappears.

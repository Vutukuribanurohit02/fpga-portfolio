# Project 06 — Polynomial Formal Verification (DATE 2024 reimplementation)

**One line:** a reimplementation of Weingarten et al.'s per-instruction BDD equivalence-checking methodology on this portfolio's own RV32I ALU, using entirely open-source tools — reproducing most of the published results and correcting two of my own earlier explanations along the way.

---

## What it is

Not a design project. A **research reimplementation**.

The paper (DATE 2024) presents a methodology for proving RV32I ALU operations equivalent to reference models using Binary Decision Diagrams, and argues about the complexity class of that verification. This project applies the methodology to the ALU from Project 3, with open tooling substituted for the paper's, and attempts to reproduce the published BDD node counts.

**Status:** complete for the combinational ALU. All **10 of 10 opcodes** formally proven equivalent to an independently constructed reference model, covering all 2^64 input combinations per opcode. Six published node counts reproduced. The O(n²) complexity bound re-derived from measurement. Two of my own earlier explanations disproved by the measurements.

---

## Why this question is worth asking

Formal verification proves a design correct for *all* inputs, unlike simulation which only samples. The catch is that its time and space costs are **unpredictable** — the same technique can finish in milliseconds on one circuit and exhaust memory on a structurally similar one.

That unpredictability is what keeps formal methods out of routine design flows. An engineer can't schedule a task that might take a second or might never terminate.

**Polynomial Formal Verification** asks the narrower, more useful question: for which *classes* of circuit can verification cost be proven polynomial in the input width? If you can answer that for a class, verification becomes schedulable for everything in it.

---

## What BDDs are, briefly

A **Binary Decision Diagram** is a canonical graph representation of a Boolean function. Two functions are equivalent if and only if their reduced ordered BDDs are identical — which makes equivalence checking a graph comparison rather than a search.

The catch, and the whole subtlety of the field: **BDD size depends enormously on variable ordering.** The same function can have a linear-size BDD under one ordering and an exponential-size BDD under another.

---

## The results

### Measured node counts

For ADD, the measured BDD size per output bit follows:

```
size(bit k) = 3k + 2
```

Bit 0 costs 2 nodes, bit 31 costs 95. Summed across the output, that's the O(n²) bound — **re-derived from measurement**, not taken from the paper on faith.

### The variable-ordering result

This is the most instructive finding in the project:

| Ordering | Outcome |
|---|---|
| **Interleaved** — `a0, b0, a1, b1, …` | Succeeds |
| **Grouped** — `a0…a31, b0…b31` | Exceeded 7 GB, OOM-killed, did not terminate |

Same function. Same tool. Same machine. **The ordering alone is the difference between seconds and impossible.**

The reason is structural: in an adder, bit *k* of the output depends on `a[k]`, `b[k]` and the carry from below. Interleaved ordering keeps mutually dependent variables adjacent in the decision order, so the diagram stays narrow. Grouped ordering forces the BDD to remember all 32 bits of `a` before it sees any bit of `b`, and the width explodes.

This is the concrete demonstration of why PFV is a real research question rather than an implementation detail.

### Corrections

Two of **my own earlier explanations** were disproved by the equivalence work and corrected in the write-up. The direction matters: the paper is not wrong — it is *under-specified about its counting convention*, which is why some node counts didn't reproduce at first.

Be precise about this in conversation. "I reimplemented a DATE paper and corrected two of my own misunderstandings along the way" is honest and shows the work was real. "I disproved the authors" is a much bolder claim that the evidence doesn't support, and it would not survive a follow-up question.

---

## Toolchain substitution

The paper's tooling was replaced with open-source equivalents throughout. This is a contribution in itself: it makes the methodology reproducible by anyone, and the substitution is where several of the discrepancies with the published numbers originate.

Repository layout includes `CONCEPTS.md` (background primer), `EQUIVALENCE.md` (the equivalence work), `RESULTS.md` (measured data) and `PROJECT_PREP.md`.

---

## What this project signals

Every other project in this portfolio says "I can build and verify hardware." This one says something different: **read a current conference paper, reimplement it against your own design with different tools, reproduce most of it, and correct your own reasoning where the measurements disagreed with it.**

That is research work. It is the entry that points toward a PhD rather than toward a job — and it's worth being explicit about that when deciding where to lead with it.

---

## Honest scope

- Complete for the **combinational ALU only**. The methodology has not been extended to the sequential CPU.
- Some published node counts were not reproduced; the open discrepancies are documented rather than hidden.
- The claim is equivalence to an independently constructed reference model — the independence of that model is what the result rests on.

---

## Questions you should be able to answer

1. Why is BDD equivalence checking a graph comparison rather than a search?
2. Why does variable ordering change BDD size so dramatically, using the adder as the example?
3. What does "polynomial formal verification" mean, and why does the polynomial matter more than the constant?
4. Why is 3k+2 per output bit an O(n²) total, and what would O(n) require?
5. What made grouped ordering exhaust memory where interleaved didn't?
6. What would extending this methodology to a sequential design require?

## Where it leads

Nowhere in this portfolio yet — the sequential extension is open work. Its natural companion is the RVFI-DII project on the roadmap.

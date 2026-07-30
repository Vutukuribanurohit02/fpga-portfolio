# Project 6 — Study & Interview Prep Guide

How to *own* this project: explain it in 60 seconds or 20 minutes, defend every design
decision, and handle the hard questions honestly.

Read `CONCEPTS.md` first if any of the terminology is unfamiliar. This document assumes
you know what a BDD is; that one teaches it.

---

## Contents

1. [Why this project is worth talking about](#1-why-this-project-is-worth-talking-about)
2. [The 60-second pitch](#2-the-60-second-pitch)
3. [The 5-minute walkthrough](#3-the-5-minute-walkthrough)
4. [Every design decision, and its defence](#4-every-design-decision-and-its-defence)
5. [Know your own code](#5-know-your-own-code)
6. [Know your own numbers](#6-know-your-own-numbers)
7. [Anticipated questions](#7-anticipated-questions)
8. [Handling the caveats](#8-handling-the-caveats)
9. [Things not to say](#9-things-not-to-say)
10. [A study plan](#10-a-study-plan)

---

## 1. Why this project is worth talking about

Most student portfolios contain designs. Very few contain *verification methodology*, and
almost none contain an attempt to reproduce a published research result.

What makes this one land:

- **It is not a tutorial.** There was no guide. The paper's tools were never released, so
  the method had to be reconstructed from a prose description.
- **It reproduces exact numbers.** 97 and 161, matching the paper's Table III.
- **It reproduces a structural result independently.** The O(n²) growth bound was
  *measured*, not assumed — with a closed form derived from the data.
- **It found a real methodological problem.** BDD counts are unreproducible without a
  stated variable order. That is a legitimate critique of the source paper.
- **It documents what did not work.** Which, to an experienced verification engineer, is
  the most credible part.

The last point matters more than it sounds. Anyone can claim a project succeeded. Being
able to say precisely where your reproduction diverged from the published result — and
why you did not paper over it — reads as engineering maturity.

---

## 2. The 60-second pitch

Practise this until it is automatic. Career-fair conditions: loud room, 30 seconds of
attention, interviewer has heard nine RISC-V CPUs already today.

> "I took a DATE 2024 paper on polynomial formal verification of a RISC-V processor and
> reimplemented its verification methodology against my own ALU.
>
> The idea is that you pin an instruction's opcode, use constant propagation to extract
> just that instruction's sub-circuit, convert it to an And-Inverter Graph, and build a
> BDD from it. The BDD's node count is a fingerprint of the function, so you can compare
> against the paper's published numbers.
>
> Their tools were never released, so I rebuilt the flow with Yosys and py-aiger. I
> reproduced their AND and XOR node counts exactly — 97 and 161. For ADD I got 1553
> against their 1327, but the per-bit growth came out exactly linear at 3k+2 nodes per
> output bit, which confirms the O(n²) bound that's the paper's actual claim.
>
> The interesting part was that BDD size depends entirely on variable ordering. With a
> bad order the same circuit exhausted 7 GB and got OOM-killed. That means any published
> BDD node count without a stated variable order isn't reproducible — including theirs."

**Why this works:** it states the problem, the method, a concrete verified result, an
honest divergence, and ends on a finding that is *yours*, not the paper's.

---

## 3. The 5-minute walkthrough

The structure to use when someone says "walk me through it."

### (a) The problem — 30 s

Simulation samples inputs; formal verification proves correctness for all of them. But
formal verification's cost is unpredictable — the same technique may take milliseconds or
exhaust memory. PFV asks whether, for a given class of circuits, you can *bound* that
cost polynomially. If you can, verification becomes something you can schedule and budget.

### (b) The scoping decision — 45 s

The DATE 2024 paper's headline contribution is verifying the *sequential* control FSM of
a multi-cycle processor. My CPU is single-cycle — no control FSM, everything in one clock
edge. So that contribution does not apply.

But the paper reports full results for the *combinational* Execute unit, Table III,
30-plus instructions with exact node counts. That maps onto my ALU exactly. So I
retargeted to the combinational methodology.

*(This is the single best thing to say in the whole walkthrough. It shows you read the
paper critically rather than treating it as a recipe.)*

### (c) The flow — 90 s

Four steps:

1. **Pin the opcode.** A wrapper module instantiates the ALU with `alu_op` tied to a
   constant.
2. **Extract.** Yosys constant propagation deletes the nine unselected datapaths, leaving
   only that instruction's logic. This substitutes for their PSIM ternary simulator —
   and it is faithful, because the paper describes setting opcode bits to constants and
   data bits to `x`, which is exactly what constant propagation with free inputs does.
3. **Convert to AIG.** `aigmap` reduces everything to two-input ANDs and inverters,
   written out as AIGER.
4. **Build the BDD** and count nodes.

Verification that step 2 worked is the AIGER header: 64 inputs, not 68. The four opcode
bits are gone.

### (d) The results — 90 s

AND = 97, XOR = 161 — exact matches.

ADD = 1553 vs their 1327. But look at the per-bit profile: 3, 5, 8, 11, 14 … 95. The
differences are constant at +3. Closed form 3k+2. Perfectly linear per output bit,
which sums to Θ(n²) — the paper's Addition-group bound.

That +3 per bit is the ripple-carry signature. Each output bit depends on one more carry
variable, costing a constant number of nodes under interleaved ordering.

### (e) The finding — 45 s

Variable ordering. Interleaved (`a0, b0, a1, b1…`) builds ADD in half a second.
Grouped (`a0…a31, b0…b31`) never finishes — 7 GB, OOM-killed, took WSL down with it.

Then I discovered py-aiger iterates inputs in hash order, which is seed-dependent per
process. The same code gave 6036 nodes on one run and 6585 on the next. Pinning
`PYTHONHASHSEED=0` and declaring the order explicitly fixed it.

The general consequence: a BDD node count published without its variable order is not
reproducible.

---

## 4. Every design decision, and its defence

Be ready to justify each of these. Interviewers probe choices, not outcomes.

### "Why retarget to the combinational methodology?"

Because the paper's sequential contribution requires a multi-cycle control FSM
(pathways `INIT→FETCH→DECODE→EXECUTE→FETCH` etc.), and a single-cycle CPU has none.
Applying it would produce meaningless output. The combinational Execute-unit
methodology, which the paper reports in full, maps onto my design exactly.

### "Why is Yosys constant propagation a valid substitute for PSIM?"

The paper describes their stimuli generation as: opcode bits set per instruction type,
operand-selection bits set, remaining data bits assigned `x`. Ternary simulation with
constants on control and `x` on data reduces to precisely the sub-circuit that constant
propagation produces when you tie the opcode and leave `a`/`b` free. It is the same
operation expressed in different tooling.

### "Why the pure-Python BDD backend instead of CUDD?"

Node counts are a property of the Boolean function and the variable order — not of the
implementation. Any correct ROBDD package with the same order gives the same count. Only
wall-clock time differs, and the largest BDD here is ~1600 nodes, so it is irrelevant.
CUDD would only be needed to compare *timings* against their published milliseconds.

### "Why leave `zero` unconnected in the wrappers?"

Table III measures the ALU's result datapath. Including the `zero` flag would add a
32-input reduction tree to every BDD and make the counts incomparable. Scoping to the 32
result bits matches what the paper measures.

### "Why interleaved ordering?"

Because ripple-carry addition is linear under it and exponential under grouped ordering.
Under grouped order the BDD must distinguish all 2³² values of `a` before seeing any bit
of `b`. Under interleaved order it only ever tracks one carry bit. This is the classic
BDD ordering result and it is the mechanism the paper's polynomial claim rests on.

### "Why separate the Yosys and Python environments?"

They never need to share an interpreter — Yosys writes a file, Python reads it. Yosys
lives in a nix-shell whose Python is 3.13; the BDD stack is a 3.12 venv. Forcing them
together caused the original install failure. Keeping them separate is both simpler and
more robust.

### "Why pin the hash seed?"

Because without it the results are not reproducible run-to-run. That is not a
convenience; it is a correctness requirement for anything claiming to reproduce published
numbers.

---

## 5. Know your own code

You must be able to explain any line of these. Read them before any interview.

### `rtl/alu_pinned.sv`

Three wrapper modules. Each instantiates `alu` with a literal `alu_op` and an
unconnected `zero`. That is the whole file — its simplicity is the point: the extraction
work is done by the synthesiser, not by hand-editing RTL.

### `scripts/extract.sh`

The Yosys pass order matters and you should know why each is there:

| Pass | Why |
|---|---|
| `read_verilog -sv` | parse both files |
| `hierarchy -top alu_${OP}` | select the wrapper; discards unused wrappers |
| `proc` | convert `always_comb` processes into a netlist of muxes |
| `flatten` | inline the `alu` instance so constants can cross the boundary |
| `opt -full` | **the constant propagation step** — the PSIM equivalent |
| `techmap` | map `$add`, `$shl` etc. onto gate-level primitives |
| `opt -full` | clean up after techmap |
| `aigmap` | reduce everything to AND + inverter |
| `write_aiger -ascii -symbols` | emit AIGER with signal names preserved |

`flatten` before `opt` is essential — without it, the constant opcode cannot propagate
into the ALU instance and nothing gets eliminated.

### `scripts/profile2.py`

Four phases:

1. **Re-exec with `PYTHONHASHSEED=0`.** The script relaunches itself if the seed is not
   already pinned, because Python fixes hash randomisation at interpreter start.
2. **Probe.** Call `to_bdd` once on a throwaway manager purely to read back the real
   input → BDD-variable mapping (`i2v`). This mapping is arbitrary and must be *read*,
   never assumed.
3. **Declare.** Sort inputs by `(bit_index, a_before_b)` and declare them to a fresh
   manager in that order, fixing the levels before any construction.
4. **Build and measure.** One BDD per output bit in a shared manager; print sizes and
   first differences.

**Know why the probe exists.** An earlier version assumed variables were named `x1..xN`
in sorted input order. Reading the actual mapping showed `a[5]→x1, b[30]→x2, a[17]→x3` —
arbitrary. That bug produced a scrambled "interleave" that silently degraded to a bad
order and OOM-killed the machine. The lesson generalises: read the tool's actual output
rather than predicting it.

---

## 6. Know your own numbers

Memorise these. Fumbling your own results is the fastest way to look like you did not do
the work.

| Quantity | Value |
|---|---|
| AND node count (theirs / mine) | 97 / **97** |
| XOR node count (theirs / mine) | 161 / **161** |
| ADD node count (theirs / mine) | 1327 / **1553** (+17%) |
| ADD per-bit closed form | `3k + 2` for k ≥ 1, `3` for k = 0 |
| ADD per-bit increment | +3 nodes |
| ADD bit 0 / bit 31 | 3 / 95 |
| AIGER inputs / latches | 64 / 0 |
| AIG gate counts (AND/XOR/ADD) | 32 / 96 / 346 |
| ADD build time, good order | ~0.5 s |
| ADD build, bad order | never finished, 7 GB, OOM |
| Instability from unpinned hash seed | 6036 vs 6585 nodes |

And the decompositions:

```
AND: 64 vars + 32 gates + 1 terminal = 97
XOR: 64 vars + 96 gates + 1 terminal = 161
```

---

## 7. Anticipated questions

### Easy

**"What's a BDD?"**
A canonical graph representation of a Boolean function. Each node tests one variable and
branches two ways; identical sub-graphs are shared. With a fixed variable order, two
functions are equal if and only if their BDDs are the identical graph — so equivalence
checking becomes a pointer comparison instead of a 2ⁿ enumeration.

**"Why not just simulate?"**
64 inputs means 2⁶⁴ ≈ 1.8×10¹⁹ input combinations. At a billion vectors per second that
is roughly 580 years. Formal methods cover the whole space structurally.

**"What's an AIG?"**
And-Inverter Graph — a netlist reduced to only two-input AND gates and inverters. It is a
minimal, uniform representation, which makes tools that consume it simple.

### Medium

**"Why does variable ordering matter so much?"**
A BDD reading variables top-down must encode everything it still needs to remember in its
node structure. For addition under grouped ordering, after reading all of `a` it must
distinguish 2³² different values, forcing exponentially many nodes. Interleaved, it only
needs the current carry bit — two states — so it stays linear.

**"Would this work on a multiplier?"**
No, and that is a famous result. Bryant proved in 1991 that multiplier BDDs are
exponential for *every* variable ordering. It is not a matter of finding a better order.
That is exactly why the paper restricts itself to RV32I base and excludes the M extension.

**"How do you know your extraction is correct?"**
The AIGER header. 64 inputs instead of 68 proves the opcode bits were eliminated; 0
latches proves it is combinational; and the gate counts are structurally sensible —
1/bit for AND, 3/bit for XOR, ~11/bit for a ripple-carry adder.

### Hard

**"Your ADD is 17% off. Is your circuit wrong?"**
No, and the per-bit profile is the evidence. Growth is exactly linear at +3 nodes/bit
with closed form 3k+2 — the ripple-carry signature. If my adder were structurally
different I would expect a different growth *shape*, not just a different constant. The
shape is what the paper's complexity claim is about, and it matches. The constant depends
on node-accounting details the paper does not specify.

**"Then how do you explain the exact AND and XOR matches?"**
Carefully — they may be coincidental. The metric that matches is total manager nodes,
which decomposes to (#vars + #AIG gates + 1). For bitwise operations, where each output
bit is independent and nothing is shared, that happens to equal the BDD structure. For
ADD it does not, because the manager also holds all 346 carry-chain intermediates. So I
can reproduce two of their numbers but I cannot claim to have identified their convention.

**"What would you do next?"**
Build the Reference Model Generator. Right now I construct BDDs and compare node counts
against published values, which is a strong fingerprint but not an equivalence proof.
The RMG builds an independent BDD from the ISA definition; checking identity against the
circuit BDD in a shared manager is what makes it actual equivalence checking.

**"Isn't node count a weak form of validation?"**
It is a necessary but not sufficient condition — two different functions could in
principle share a count. It is strong evidence of a faithful reimplementation, which is
what it was used for here, and weak evidence of circuit correctness, which is what the
RMG will address. I would not overclaim it.

---

## 8. Handling the caveats

Three things went unresolved. Present them as findings, calmly, without apology.

**The 17% ADD gap.** Lead with the structural match. "The complexity result reproduces;
the constant does not, and here is my hypothesis about why."

**The uncertain convention.** This is the strongest honest move available. "I can
reproduce two of their numbers exactly, but when I checked *why*, the metric turned out
to track gate count rather than BDD structure — so I'm not confident the match is
meaningful. I'd rather say that than claim I've reverse-engineered their method."

Saying this out loud is worth more than a clean result would be. It demonstrates that you
audit your own successes, not just your failures.

**The missing RMG.** State the scope precisely: "This implements extraction and BDD
construction. Equivalence checking against an independent reference model is the next
piece." Do not describe the project as complete equivalence checking — someone will ask
where the reference model is.

---

## 9. Things not to say

- ❌ "I verified my ALU using the paper's method." — You reproduced node counts. The
  equivalence check is not built yet.
- ❌ "I got the same results as the paper." — You got two of them.
- ❌ "BDDs are always better than SAT." — They are complementary; BDDs are canonical but
  memory-hungry, SAT scales further on many problems but gives no canonical form.
- ❌ "The paper is wrong." — The paper is under-specified about its counting convention.
  That is a reproducibility gap, not an error.
- ❌ Any claim you cannot back with a number from section 6.

---

## 10. A study plan

Roughly four hours, spread over a few sessions.

**Session 1 — Concepts (90 min).** Read `CONCEPTS.md` end to end. Then, without looking:
draw the BDD for a 2-bit comparator under both interleaved and grouped ordering and count
nodes. If you can do that from scratch, you understand the core result.

**Session 2 — Your own flow (60 min).** Open `extract.sh` and explain each Yosys pass out
loud. Then open `add.aag` and read the header and the first ten AND lines. Trace one
output bit back a couple of levels by hand.

**Session 3 — Your own results (45 min).** Re-derive `3k+2` from the printed per-bit
sizes. Verify Σ(3k+2) for k=1..31, plus 3, equals 1553. Memorise section 6.

**Session 4 — Rehearsal (45 min).** Say the 60-second pitch aloud five times. Then have
someone ask the "hard" questions from section 7 cold.

**Optional depth.** Read Bryant's 1986 paper *"Graph-Based Algorithms for Boolean
Function Manipulation"* — it is the origin of everything here and is unusually readable
for a foundational paper.

# Concepts — Everything Behind Project 6, From the Ground Up

This document assumes you know digital logic (gates, adders, RTL) and nothing else. It
builds up to the point where every line of the project makes sense.

Read it in order. Each part depends on the one before.

---

## Contents

- [Part 0 — Why verification is hard](#part-0--why-verification-is-hard)
- [Part 1 — Representing Boolean functions](#part-1--representing-boolean-functions)
- [Part 2 — Binary Decision Diagrams](#part-2--binary-decision-diagrams)
- [Part 3 — Variable ordering](#part-3--variable-ordering-the-make-or-break)
- [Part 4 — Where BDDs fail](#part-4--where-bdds-fail)
- [Part 5 — And-Inverter Graphs and AIGER](#part-5--and-inverter-graphs-and-aiger)
- [Part 6 — Synthesis as a verification tool](#part-6--synthesis-as-a-verification-tool)
- [Part 7 — Equivalence checking](#part-7--equivalence-checking)
- [Part 8 — Complexity and Polynomial Formal Verification](#part-8--complexity-and-polynomial-formal-verification)
- [Part 9 — The RV32I ALU](#part-9--the-rv32i-alu)
- [Part 10 — Putting it together](#part-10--putting-it-all-together)
- [Glossary](#glossary)
- [Further reading](#further-reading)

---

## Part 0 — Why verification is hard

### The combinatorial wall

Your ALU takes `a[31:0]`, `b[31:0]`, and `alu_op[3:0]` — 68 input bits. The number of
distinct input combinations is

```
2^68 ≈ 2.95 × 10^20
```

Simulate a billion vectors per second and exhaustive testing takes about **9,300 years**.
Even pinning the opcode leaves 2⁶⁴ ≈ 1.8×10¹⁹ combinations — around 580 years.

So simulation cannot be exhaustive. It samples. A directed or constrained-random testbench
covers the cases you thought of, and misses the ones you did not. The Pentium FDIV bug of
1994 was five missing table entries out of 1,066, hit by a vanishingly small fraction of
inputs, and it cost Intel roughly $475 million.

### Two kinds of verification

| | Simulation | Formal verification |
|---|---|---|
| Coverage | Sampled inputs | All inputs, structurally |
| Result | "No bug found in these vectors" | "No bug exists" (or a counterexample) |
| Scales with | Number of vectors | Circuit structure |
| Cost | Predictable | **Unpredictable** |

That last row is the whole motivation for this project. Formal verification's strength is
completeness; its weakness is that you cannot say in advance whether a proof will take a
millisecond or exhaust your RAM. Two circuits of similar size can behave completely
differently.

That unpredictability keeps formal methods out of routine flows. You cannot schedule a
task whose runtime might be unbounded.

**Polynomial Formal Verification** is the research programme that attacks this: for a
given class of circuits, prove an upper bound on verification cost that is polynomial in
the circuit size. That converts formal verification from a gamble into a budget line.

---

## Part 1 — Representing Boolean functions

A Boolean function maps n input bits to one output bit. To reason about one mechanically,
you need to store it somehow. The representation you choose determines what is easy.

### Truth tables

List every input combination and its output.

| a | b | a∧b |
|---|---|---|
| 0 | 0 | 0 |
| 0 | 1 | 0 |
| 1 | 0 | 0 |
| 1 | 1 | 1 |

**Good:** canonical — one function, one table. Comparing two functions is comparing two
tables.
**Fatal:** 2ⁿ rows. At n=64 the table does not fit in the universe.

### Formulas

`f = (a ∧ b) ∨ (c ∧ ¬d)`.

**Good:** compact.
**Fatal:** *not* canonical. `a∧b` and `¬(¬a ∨ ¬b)` are the same function written
differently. Deciding whether two formulas are equal is co-NP-complete. You cannot just
compare them.

### Circuits / netlists

A graph of gates.

**Good:** compact, matches hardware.
**Fatal:** not canonical either. Two structurally different netlists can implement the
same function.

### What we actually want

A representation that is:

1. **Canonical** — equal functions have *identical* representations, so equivalence
   checking is cheap.
2. **Compact** — sub-exponential for the functions we care about.
3. **Manipulable** — you can compute AND, OR, NOT of two representations efficiently.

Truth tables give 1 and 3 but not 2. Formulas give 2 and 3 but not 1.

BDDs give all three — for many useful functions.

---

## Part 2 — Binary Decision Diagrams

### Start with a decision tree

Take `f = (a ∧ b) ∨ c`. Ask about each variable in turn. Dashed edge = variable is 0,
solid edge = variable is 1.

```
                 (a)
             0 /     \ 1
             /         \
          (b)           (b)
        0/   \1       0/   \1
       (c)   (c)     (c)   (c)
      0/ \1 0/ \1   0/ \1 0/ \1
      0   1 0   1   0   1 1   1
```

This is just a truth table drawn as a tree — 2ⁿ leaves. No progress yet.

### Reduction rule 1 — merge identical sub-graphs

Several of those `(c)` nodes are structurally identical: same variable, same 0-child,
same 1-child. Keep one copy and point everything at it. This is *hash-consing*, and it is
what turns the tree into a directed acyclic **graph**.

### Reduction rule 2 — delete redundant tests

If a node's 0-edge and 1-edge lead to the same place, the test does not matter. Delete the
node and connect its parent straight through.

Look at the rightmost `(b)` above: when `a=1, b=1`, the result is 1 regardless of `c`.
Both its children collapse to the constant 1, so that whole subtree becomes a single edge
to the terminal.

### The result: a Reduced Ordered BDD

Apply both rules until neither applies. `f = (a ∧ b) ∨ c` becomes roughly:

```
        (a)
       /   \
      /     (b)
     |     /   \
      \   /     \
       (c)       \
      /   \       \
    [0]   [1] ←────┘
```

Two properties define an **ROBDD**:

- **Ordered** — every path tests variables in the same fixed order.
- **Reduced** — both reduction rules have been applied exhaustively.

### The theorem that makes it all work

> **For a fixed variable order, the ROBDD of a Boolean function is unique.**
> (Bryant, 1986)

This is the payoff. If two functions are equal, their ROBDDs are *the same graph*. In a
shared BDD manager, where all functions live in one hash-consed table, they are literally
the same node — the same pointer.

**Equivalence checking becomes a pointer comparison.** O(1), instead of 2ⁿ.

This is why the whole field exists.

### How BDDs get built: Shannon expansion

Any Boolean function decomposes around any variable:

```
f = (x ∧ f|ₓ₌₁) ∨ (¬x ∧ f|ₓ₌₀)
```

`f|ₓ₌₁` is the *cofactor*: f with x replaced by 1. A BDD node **is** this decomposition —
the node tests x, its 1-edge points to the positive cofactor, its 0-edge to the negative
one.

### The ITE operator

Every Boolean operation reduces to one primitive:

```
ite(g, u, v) = (g ∧ u) ∨ (¬g ∧ v)      "if g then u else v"
```

Because:

```
u ∧ v  =  ite(u, v, 0)
u ∨ v  =  ite(u, 1, v)
u ⊕ v  =  ite(u, ¬v, v)
¬u     =  ite(u, 0, 1)
```

A BDD package implements exactly one recursive algorithm — `ite` — plus a memo table.
When you saw `_ite` repeated hundreds of times in the stack traces during this project,
that was `dd` recursing through the Shannon decomposition of the adder.

**Useful size facts** (worth remembering, they appear in the paper): a single variable's
BDD is 3 nodes (the variable node plus two terminals). A 3-variable ITE is 7 nodes.

---

## Part 3 — Variable ordering (the make-or-break)

Everything above said "for a *fixed* variable order." That qualifier is doing enormous
work.

### The classic example

Consider

```
f = (x₁ ∧ y₁) ∨ (x₂ ∧ y₂) ∨ … ∨ (xₙ ∧ yₙ)
```

**Interleaved order** `x₁, y₁, x₂, y₂, …, xₙ, yₙ`: the BDD has **2n + 2 nodes** — linear.

**Grouped order** `x₁, x₂, …, xₙ, y₁, …, yₙ`: the BDD has **2ⁿ⁺¹ nodes** — exponential.

Same function. Same reduction rules. Only the order changed.

### Why — the intuition worth internalising

Think of the BDD as a machine reading variables top to bottom. Everything it still needs
to remember must be encoded in *which node it is currently at*. Node count at a level =
number of distinct things it must remember.

Under **grouped** ordering, after reading all of `x₁…xₙ` and before seeing any `y`, the
machine cannot have decided anything — every `xᵢ` might still matter depending on `yᵢ`.
So it must remember the entire n-bit pattern of x. That is 2ⁿ distinct states, hence 2ⁿ
nodes at that level.

Under **interleaved** ordering, after reading `x₁, y₁` it knows whether that pair already
made the function true. It carries forward one bit — "satisfied so far, yes or no." Two
states per level. Linear.

**Good ordering = the function needs little memory as you sweep through the variables.**

### Applying this to an adder

For `s = a + b`, output bit k depends on `a[k]`, `b[k]`, and the carry into position k.
The carry is a single bit summarising everything below.

- **Interleaved** (`a[0], b[0], a[1], b[1], …`): after processing bit position k, the only
  thing to remember is the carry — 1 bit, 2 states. Each additional bit costs a constant
  number of nodes. **Linear per output bit.**
- **Grouped** (`a[0..31], b[0..31]`): after reading all 32 bits of `a`, nothing can be
  decided until `b` arrives, so all 2³² values of `a` must be distinguished.
  **Exponential.**

This is exactly what was observed in the project:

| Ordering | ADD result |
|---|---|
| Interleaved | 1553 nodes, 0.5 s |
| Grouped | Did not terminate; 7 GB exhausted, OOM-killed |

And the measured per-bit growth under interleaving was `3k + 2` — constant increment of
+3 nodes per bit, exactly as the carry argument predicts.

### Finding a good order

- **Static heuristics** — derive an order from circuit topology, e.g. inputs that are
  close together in the netlist should be close together in the order.
- **Dynamic reordering (sifting)** — the package periodically moves variables up and down
  levels, keeping whatever shrinks the graph. This is what `manager.configure(reordering=True)`
  enables. It helps, but it finds local minima: in this project sifting rescued ADD from
  non-termination but landed at 8885 nodes, where explicit interleaving reached 1553.
- **Domain knowledge** — you know it is an adder, so you know interleaving is right. This
  beats both of the above and is what the paper does.

> **Finding the optimal variable order is NP-complete.** In practice you use domain
> knowledge and accept "good enough."

---

## Part 4 — Where BDDs fail

### Multipliers

> **Theorem (Bryant, 1991):** The BDD for the middle output bit of an n-bit multiplier
> has size at least 2^(n/8) **for every variable ordering.**

Not "for bad orderings." For all of them. There is no clever order to find.

This single result shapes the entire research area, and it explains a design decision in
the paper: the methodology targets **RV32I base only** and explicitly excludes the M
extension (multiply/divide). That is not laziness — it is a hard mathematical boundary.

For multipliers you need different machinery: Binary Moment Diagrams (\*BMDs), or Symbolic
Computer Algebra, which reasons about polynomials over the integers rather than Boolean
functions.

### The general picture

| Function class | BDD behaviour |
|---|---|
| Bitwise logic (AND, OR, XOR) | Tiny, order-insensitive |
| Comparators, adders, shifters | Linear-to-quadratic with a good order |
| Multipliers | Exponential for every order |
| Hash functions, cryptographic S-boxes | Hopeless |

### BDDs vs SAT

Modern equivalence checking often uses SAT solvers instead. The trade-off:

| | BDD | SAT |
|---|---|---|
| Canonical form | Yes | No |
| Equivalence check | Pointer compare, O(1) | Solve a miter instance |
| Memory | Can explode | Usually modest |
| Scales to | ~100s of variables for hard functions | Millions of variables |
| Gives you | The whole function | One yes/no answer + witness |

They are complementary, not competitors. BDDs are chosen here because a canonical form is
what makes *node counting* meaningful as a fingerprint — a SAT solver would give you a
yes/no with no comparable metric.

---

## Part 5 — And-Inverter Graphs and AIGER

### Why a special netlist format

Real netlists have dozens of cell types. A tool that consumes them must handle all of
them. But every Boolean function can be built from just two primitives:

- 2-input AND
- inverter

An **And-Inverter Graph** is a netlist restricted to exactly that. Inverters are usually
stored as a bit on the edge rather than as nodes, so an AIG is a DAG of 2-input ANDs with
complemented edges.

**Why it is the right interchange format:** uniformity. A BDD builder consuming an AIG
needs exactly one rule — `bdd(gate) = bdd(left) ∧ bdd(right)`, negating where the edge
says so. That is the whole algorithm. (You saw this line in a traceback during the
project: `gate_nodes[gate] = gate_nodes[gate.left] & gate_nodes[gate.right]`.)

### Standard AIG encodings

| Function | Built from AND + inverter | Gate cost |
|---|---|---|
| `¬a` | edge complement | 0 |
| `a ∧ b` | one AND | 1 |
| `a ∨ b` | `¬(¬a ∧ ¬b)` (De Morgan) | 1 |
| `a ⊕ b` | `¬(¬(a∧¬b) ∧ ¬(¬a∧b))` | 3 |

This explains the observed gate counts exactly: 32-bit AND → 32 gates; 32-bit XOR → 96
gates (3 per bit); 32-bit ripple-carry ADD → 346 gates (~10.8 per bit, since a full adder
is two XORs plus carry logic).

### The AIGER format

The header line is:

```
aag  M  I  L  O  A
```

| Field | Meaning |
|---|---|
| `M` | maximum variable index |
| `I` | number of primary inputs |
| `L` | number of latches (sequential elements) |
| `O` | number of primary outputs |
| `A` | number of AND gates |

From the project:

```
aag  96 64 0 32  32     ← and.aag
aag 160 64 0 32  96     ← xor.aag
aag 410 64 0 32 346     ← add.aag
```

**How to read these as a correctness check:**

- `I = 64` — only `a[31:0]` and `b[31:0]` survive. The 4 opcode bits are gone, proving
  constant propagation eliminated them. Had it been 68, extraction failed.
- `L = 0` — no latches. The design is purely combinational, as expected.
- `O = 32` — the 32 result bits. `zero` was deliberately left unconnected.
- `A` — grows with operation complexity, matching the table above.

Literals are encoded as `2 × variable_index` for the positive form and `2 × index + 1`
for the negated form, so the low bit is the inversion flag.

---

## Part 6 — Synthesis as a verification tool

Yosys is a synthesis tool, but here it is used as a *program transformer* — the trick that
replaces the paper's PSIM.

### The pipeline

```
read_verilog -sv rtl/alu.sv rtl/alu_pinned.sv
hierarchy -top alu_add     # pick the pinned wrapper
proc                       # always_comb → mux netlist
flatten                    # inline the alu instance
opt -full                  # ← constant propagation
techmap                    # $add, $shl → gate primitives
opt -full
aigmap                     # everything → AND + inverter
write_aiger -ascii -symbols aig/add.aag
```

### What each pass does, and why the order matters

**`hierarchy -top`** selects the design root and discards unreachable modules. Choosing
`alu_add` immediately drops `alu_and` and `alu_xor`.

**`proc`** converts behavioural processes into structural logic. Your `case (alu_op)`
becomes a 10-way multiplexer with all ten datapaths built and one selected.

**`flatten`** inlines the `alu` instance into the wrapper. **This must come before `opt`.**
The constant `4'b0000` lives in the wrapper; the mux lives inside `alu`. Until the module
boundary is dissolved, the constant cannot reach the mux and nothing gets eliminated.

**`opt -full`** is the key step. With `alu_op` constant, the multiplexer's select is
known, so nine of its ten data ports are unreachable. Yosys deletes them, then deletes the
now-unused logic feeding them. In the project's Yosys log this appears as:

```
dead port 1/11 on $pmux ...
Removed 10 multiplexer ports.
Removed 10 unused cells and 25 unused wires.
```

That is the per-instruction sub-circuit extraction — done by a synthesiser instead of a
bespoke ternary simulator.

**`techmap`** expands arithmetic operators into gates. `$add` becomes a chain of full
adders. Note this is where the *adder architecture* is decided — Yosys's default expansion
is ripple-carry, which is why the measured growth matched the paper's RCA reference model.

**`aigmap`** reduces every remaining cell to AND + inverter.

### Why this substitution is legitimate

The paper describes PSIM as ternary simulation: opcode bits set to constants, data bits
set to `x` (unknown), then graph reduction — nodes evaluating to a constant are removed,
and fan-ins that cannot affect outputs are pruned.

Constant propagation with constant opcode and free data inputs performs precisely those
operations. Same transformation, different implementation.

---

## Part 7 — Equivalence checking

### The general problem

Given two representations of a function — say a circuit and a specification — prove they
compute the same thing for all inputs.

### The miter construction (SAT-based)

Feed both designs the same inputs, XOR corresponding outputs, OR all the XORs:

```
        ┌─────────┐
   ────▶│ design  │──┬──▶ XOR ──┐
        └─────────┘  │          │
inputs               │          ├─▶ OR ─▶ miter output
        ┌─────────┐  │          │
   ────▶│  spec   │──┴──▶ XOR ──┘
        └─────────┘
```

The miter output is 1 exactly when the designs disagree. Ask a SAT solver whether it can
ever be 1. UNSAT means equivalent; SAT gives you a counterexample input.

### The BDD approach (used here)

Build ROBDDs for both in a **shared manager** with the **same variable order**. By
canonicity, they are equivalent iff the BDDs are the identical node.

```python
circuit_bdd = build_from_aig(circuit, manager)
reference_bdd = build_from_spec(spec, manager)
equivalent = (circuit_bdd == reference_bdd)   # pointer comparison
```

Or equivalently, check that `circuit_bdd ⊕ reference_bdd` is the constant 0.

Both requirements are essential. **Shared manager**, so identical sub-graphs are the same
objects. **Same order**, or canonicity does not apply and the comparison is meaningless.

### What the paper's Reference Model Generator does

The RMG builds the reference BDD independently — not from the circuit, but from the ISA
definition. For each instruction group it uses a direct functional model:

- **Logic group** (AND, OR, XOR + immediates) — bitwise operations
- **Addition group** (ADD, ADDI, JAL, JALR, LOAD/STORE address computation) — an adder
  function
- **Subtraction group** (SUB, branches, SLT/SLTU) — a subtractor, realised as
  `A − B = A + ¬B + 1`
- **Shift group** (SLL, SRL, SRA + immediates) — a generic shifter

The paper notes the RMG deliberately generates the *same variable ordering* SYMSIM uses —
which, per Part 3, is not an optimisation but a correctness requirement for the comparison
to mean anything.

### Where this project currently stands

Built: extraction, AIG conversion, BDD construction, node counting.
Not built: the RMG, and therefore the equivalence check itself.

Node counts are a strong *fingerprint* — matching 97 and 161 exactly is real evidence the
extracted functions are the intended ones. But a fingerprint is a necessary, not
sufficient, condition. Two different functions could in principle share a node count. The
RMG is what closes that gap.

---

## Part 8 — Complexity and Polynomial Formal Verification

### Big-O, briefly

`O(f(n))` bounds growth as n grows. For an n-bit datapath:

| Bound | Meaning at n=32 | Verdict |
|---|---|---|
| O(n) | ~32 | trivial |
| O(n²) | ~1,024 | fine |
| O(n³) | ~33,000 | usually fine |
| O(2ⁿ) | ~4.3 billion | hopeless |

The line that matters is polynomial vs exponential.

### What PFV actually claims

Not "verification is fast." The claim is: *for this class of designs, we can prove an
upper bound that is polynomial in circuit size.*

The value is **predictability**. If ALU verification is O(n²), doubling the datapath width
quadruples the cost — you can plan for that. If it is exponential, you cannot plan
anything.

### The paper's bounds

| Unit | Bound | Reasoning |
|---|---|---|
| Fetch | O(n) | reset + read + read/write, each O(n) |
| Decode + Extension | O(n²) | bitwise MUX inference; each ITE is a constant 7 nodes |
| Execute — Logic | O(n) | bit-independent |
| Execute — Shift | O(n) | generic shifter |
| Execute — Addition | O(n²) | n outputs × O(n) each |
| Execute — Subtraction | O(n²) | same as addition via `A + ¬B + 1` |
| Control | O(k·m) | k instructions × m FSM states |

### How this project verified the Addition bound independently

Not by trusting the paper — by measuring.

```
bit  0 :  3
bit  1 :  5
bit  2 :  8
bit  3 : 11
...
bit 31 : 95

first differences: [2, 3, 3, 3, ..., 3]
```

Constant first difference ⇒ linear per-bit growth ⇒ closed form:

```
size(bit 0) = 3
size(bit k) = 3k + 2     for k ≥ 1
```

Total:

```
3 + Σ(k=1..31) (3k + 2)  =  3 + 3·(31·32/2) + 2·31  =  3 + 1488 + 62  =  1553  ✓
```

Since each of n outputs costs O(n), the total is **Θ(n²)** — the paper's Addition-group
bound, derived from your own measurements.

This is the strongest result in the project. Absolute node counts depend on accounting
conventions the paper does not fully specify; the *growth exponent* does not. It is the
part that is genuinely reproducible, and it reproduced.

---

## Part 9 — The RV32I ALU

Brief grounding on the design under verification.

### Interface

```systemverilog
module alu #(parameter int WIDTH = 32) (
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  logic [3:0]       alu_op,
    output logic [WIDTH-1:0] result,
    output logic             zero
);
```

Purely combinational — no clock, no state. That is why `L = 0` in every AIGER header.

### Operations

| `alu_op` | Op | Function | RISC-V instructions served |
|---|---|---|---|
| 0000 | ADD | `a + b` | ADD, ADDI, loads/stores, JAL, JALR, AUIPC |
| 0001 | SUB | `a − b` | SUB, and branch comparisons |
| 0010 | AND | `a & b` | AND, ANDI |
| 0011 | OR | `a \| b` | OR, ORI |
| 0100 | XOR | `a ^ b` | XOR, XORI |
| 0101 | SLT | signed `a < b` | SLT, SLTI, BLT, BGE |
| 0110 | SLTU | unsigned `a < b` | SLTU, SLTIU, BLTU, BGEU |
| 0111 | SLL | `a << b[4:0]` | SLL, SLLI |
| 1000 | SRL | `a >> b[4:0]` | SRL, SRLI |
| 1001 | SRA | arithmetic `a >>> b[4:0]` | SRA, SRAI |

Only `b[4:0]` is used as a shift amount — RV32I defines shifts modulo 32.

### Why one ALU serves so many instructions

This is what makes per-instruction extraction interesting. A single `ADD` datapath is
reused for arithmetic, address computation for loads and stores, and jump targets. That
is why the paper's Table III lists ADD, ADDI, JAL, JALR, AUIPC, LUI, LB and SB all with
the *identical* node count of 1327 — they are the same extracted sub-circuit.

The clustering structure of Table III is itself a checkable prediction: instructions
sharing a datapath must share a node count exactly.

### Two's complement subtraction

```
A − B = A + ¬B + 1
```

Invert B (a row of XOR gates) and set carry-in to 1. This is why the paper's Subtraction
group has the same O(n²) bound as Addition — it *is* an adder — and why SUB's node count
(1415) is slightly higher than ADD's (1327): the extra inverter row.

---

## Part 10 — Putting it all together

Now every step of the project should read as inevitable rather than arbitrary.

```
┌────────────────────────────────────────────────────────────┐
│ alu.sv — 10 operations, 68 inputs, combinational           │
└────────────────────────┬───────────────────────────────────┘
                         │  wrap with alu_op tied constant
                         ▼
┌────────────────────────────────────────────────────────────┐
│ alu_add / alu_and / alu_xor — 64 inputs, one operation     │
└────────────────────────┬───────────────────────────────────┘
                         │  Yosys: flatten + opt -full
                         │  (constant propagation = PSIM)
                         ▼
┌────────────────────────────────────────────────────────────┐
│ per-instruction sub-circuit — 9 datapaths deleted           │
└────────────────────────┬───────────────────────────────────┘
                         │  techmap + aigmap + write_aiger
                         ▼
┌────────────────────────────────────────────────────────────┐
│ add.aag — aag 410 64 0 32 346                              │
│ verify: I=64 (opcode gone), L=0 (combinational)            │
└────────────────────────┬───────────────────────────────────┘
                         │  declare interleaved order FIRST
                         │  a[0], b[0], a[1], b[1], ...
                         ▼
┌────────────────────────────────────────────────────────────┐
│ 32 ROBDDs in a shared manager                              │
│ per-bit sizes 3, 5, 8, ..., 95  →  3k+2  →  Θ(n²)  ✓       │
└────────────────────────┬───────────────────────────────────┘
                         │  [ NOT YET BUILT ]
                         ▼
┌────────────────────────────────────────────────────────────┐
│ RMG → reference BDD → identity check → equivalence proof   │
└────────────────────────────────────────────────────────────┘
```

### The five things to take away

1. **Canonicity is the whole point of BDDs.** Fixed order ⇒ unique graph ⇒ equivalence is
   a pointer comparison.
2. **Variable ordering decides everything.** The same circuit is linear or exponential
   depending on nothing but the order. Interleaved for datapath operands; that is the
   carry argument.
3. **AIG is the universal interchange format.** One gate type means one rule for any
   consumer.
4. **Constant propagation is program specialisation.** Pinning an input and letting the
   optimiser run is a general and powerful trick, well beyond this project.
5. **Growth rates reproduce; constants often do not.** When reproducing published
   results, the exponent is the robust claim; absolute numbers depend on conventions
   papers frequently leave unstated.

---

## Glossary

**AIG (And-Inverter Graph)** — netlist using only 2-input ANDs and inverters.

**AIGER** — file format for AIGs. Header `aag M I L O A`.

**BDD** — Binary Decision Diagram. Graph representation of a Boolean function.

**Canonical** — equal functions have identical representations.

**Cofactor** — `f|ₓ₌₁` is f with variable x fixed to 1.

**Hash-consing** — storing structures in a hash table so identical ones share one object;
what makes BDD sub-graph sharing work.

**ITE** — if-then-else, `ite(g,u,v) = (g∧u) ∨ (¬g∧v)`. The single primitive of a BDD
package.

**Miter** — circuit XOR-ing two designs' outputs; used for SAT-based equivalence checking.

**PFV** — Polynomial Formal Verification. Proving polynomial upper bounds on verification
cost.

**PSIM / SSIM / SYMSIM** — the paper's in-house partial, sequential, and symbolic
simulators. Never released.

**RMG** — Reference Model Generator. Builds the golden BDD from the ISA specification.

**ROBDD** — Reduced Ordered BDD. The canonical form.

**Shannon expansion** — `f = (x ∧ f|ₓ₌₁) ∨ (¬x ∧ f|ₓ₌₀)`.

**Sifting** — dynamic variable reordering by trial movement.

**Terminal node** — the constant 0 or 1 leaf of a BDD.

---

## Further reading

**Foundational**

- R. E. Bryant, *"Graph-Based Algorithms for Boolean Function Manipulation,"* IEEE Trans.
  Computers, 1986. — the origin of ROBDDs. Unusually readable; start here.
- R. E. Bryant, *"On the Complexity of VLSI Implementations and Graph Representations of
  Boolean Functions with Application to Integer Multiplication,"* 1991. — the multiplier
  lower bound.

**This project's line of work**

- Weingarten, Datta, Kole, Drechsler, *"Complete and Efficient Verification for a RISC-V
  Processor using Formal Verification,"* DATE 2024.
- Weingarten, Datta, Drechsler, *"PolyMiR: Polynomial Formal Verification of the MicroRV32
  Processor,"* NANOARCH 2023. — the actual source of Table III.
- Drechsler, Mahzoon, *"Polynomial Formal Verification: Ensuring Correctness under
  Resource Constraints,"* ICCAD 2022. — the programme statement.

**Tools**

- Yosys manual — the `opt`, `techmap`, and `aigmap` sections.
- `dd` documentation — the Python BDD package used here.
- AIGER format specification — one page, worth reading in full.

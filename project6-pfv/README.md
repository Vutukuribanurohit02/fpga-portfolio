# Project 6 — Polynomial Formal Verification of an RV32I ALU

A reimplementation of the per-instruction BDD equivalence-checking methodology from
Weingarten et al. (DATE 2024), applied to my own RV32I ALU using entirely open-source
tools, and validated by attempting to reproduce the published BDD node counts.

**Status:** complete for the combinational ALU. All **10 of 10** opcodes are
formally proven equivalent to an independently constructed reference model. Six
of the paper's published node counts reproduced. The O(n²) complexity bound
re-derived from measurement. Two of the original explanations were disproved by
the equivalence work and are corrected below.

---

## Table of contents

- [Motivation](#motivation)
- [The papers](#the-papers)
- [What was actually reimplemented](#what-was-actually-reimplemented)
- [Toolchain substitution](#toolchain-substitution)
- [How it works](#how-it-works)
- [Results](#results)
- [The variable-ordering problem](#the-variable-ordering-problem)
- [Open discrepancies](#open-discrepancies)
- [Repository layout](#repository-layout)
- [Reproducing](#reproducing)
- [Remaining work](#remaining-work)
- [References](#references)

---

## Motivation

Formal verification proves a design correct for *all* inputs, unlike simulation which
only samples. The catch is that its time and space costs are unpredictable — the same
technique can finish in milliseconds on one circuit and exhaust memory on a structurally
similar one. That unpredictability is what keeps formal methods from being a routine
part of every design flow.

**Polynomial Formal Verification (PFV)** asks a narrower question: for a given class of
designs, can we prove an upper bound on verification cost that is polynomial in the
circuit size? If yes, verification becomes *schedulable* — you can budget for it.

The Weingarten group has been establishing PFV results for adders, floating-point units,
and eventually whole RISC-V processors. This project takes their per-instruction
methodology and re-runs it against my own ALU, using open tools instead of their
unreleased in-house ones.

---

## The papers

**Primary:** L. Weingarten, K. Datta, A. Kole, R. Drechsler, *"Complete and Efficient
Verification for a RISC-V Processor using Formal Verification,"* DATE 2024.
DOI: [10.23919/DATE58400.2024.10546693](https://doi.org/10.23919/DATE58400.2024.10546693)

**Important attribution note.** The DATE 2024 paper's headline contribution is verifying
the *sequential* units (Fetch, Control) of the multi-cycle MicroRV32 processor. Its
Table III — the ALU and Decode/Extension results this project targets — is explicitly
reproduced from the group's earlier work:

> L. Weingarten, K. Datta, R. Drechsler, *"PolyMiR: Polynomial Formal Verification of
> the MicroRV32 Processor,"* NANOARCH 2023.

Any write-up of this project should cite **both**.

### Why the sequential contribution was not reimplemented

The DATE 2024 method verifies the Control unit as an FSM traversing two pathways:

```
P1 = INIT → FETCH → DECODE → EXECUTE → FETCH          (R, I, B, U, J types)
P2 = INIT → FETCH → DECODE → EXECUTE → WRITEBACK → FETCH   (S type)
```

My RV32I CPU (Project 4) is **single-cycle**. There is no multi-state control FSM to
traverse — every instruction completes in one clock edge. Applying a sequential
verification method to a design with no sequential control logic would be theatre.

So the project was retargeted to the combinational Execute-unit methodology, which maps
onto my ALU exactly.

---

## What was actually reimplemented

Be precise about scope. This project implements:

- ✅ Per-instruction sub-circuit extraction via opcode pinning (their PSIM step)
- ✅ AIG → BDD construction under a controlled variable order (their SYMSIM step)
- ✅ BDD node counting for comparison against Table III
- ✅ Complexity-growth measurement (the actual PFV claim)

- ✅ The Reference Model Generator (RMG) — golden BDDs built from RV32I semantics
- ✅ The equivalence check itself (BDD identity between circuit and reference)
- ✅ All 10 ALU opcodes

See [Equivalence checking](EQUIVALENCE.md) for the full method, the fault-injection
test, and two corrections to the original analysis.

**Headline result.** Every operation is proven equivalent to a reference model that
was built with a *deliberately different architecture* — parallel-prefix carries and
a barrel shifter, against the circuit's ripple-carry chain and cascaded shift stages.
Because ROBDDs are canonical, root equality is equivalence over all 2⁶⁴ input
combinations, checked as a pointer comparison.

```
EQUIVALENT  ADD  SUB  AND  OR  XOR  SLT  SLTU  SLL  SRL  SRA
```

The reference model is itself validated exhaustively at width 6 (4,096 assignments
per operation) against Python integer arithmetic, so a passing check cannot be
hiding a wrong golden model.

---

## Toolchain substitution

The paper's tools (`PSIM`, `SSIM`, `SYMSIM`) are in-house C++ and were never released.
Everything had to be reconstructed from the method description:

| Their tool | Purpose | Open substitute used here |
|---|---|---|
| Yosys + Berkeley-ABC | RTL → AIG | **Yosys 0.62** (`aigmap` + `write_aiger`) |
| PSIM | Ternary simulation to extract the per-instruction sub-circuit | **Yosys constant propagation** on an opcode-pinned netlist |
| SYMSIM | Symbolic simulation, AIG → BDD | **py-aiger 8.1.0** + **py-aiger-bdd 0.2.1** |
| CUDD | BDD package | **dd 0.5.7** (`dd.autoref`, pure Python) |
| RMG | Reference model generation | *not yet implemented* |

### Why Yosys constant propagation is a faithful PSIM substitute

This is the substitution most worth defending, and the paper itself supports it. Their
stimuli generation is described as: set the opcode bit-vector according to instruction
type, set other bits to select operand type, and assign remaining operand-dependent data
bits to `x` (unknown).

That is *exactly* what constant propagation does when you tie `alu_op` to a constant and
leave `a`/`b` free. Ternary simulation with `x` on the data bits and constants on the
control bits reduces to the same sub-circuit. The substitution is methodological, not a
shortcut.

### Note on `dd` backend

`pip install dd` gives the pure-Python backend, not the CUDD C bindings the paper used.
This does not affect correctness: **BDD node counts are a property of the Boolean
function and the variable order, not of the implementation.** Only wall-clock time
differs, and at this scale (largest BDD ≈ 1600 nodes) that is irrelevant.

---

## How it works

### Step 1 — Pin the opcode

`rtl/alu_pinned.sv` wraps the ALU once per instruction, tying `alu_op` to a constant and
leaving `zero` unconnected so only the 32 result bits are primary outputs:

```systemverilog
module alu_add (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result
);
    alu #(.WIDTH(32)) u (.a(a), .b(b), .alu_op(4'b0000), .result(result), .zero());
endmodule
```

### Step 2 — Extract the sub-circuit

`scripts/extract.sh` runs Yosys, which propagates the constant opcode through the
`case` statement, deletes the nine unselected datapaths, and emits an AIGER file:

```
read_verilog -sv rtl/alu.sv rtl/alu_pinned.sv
hierarchy -top alu_${OP}
proc            # processes → netlist
flatten         # inline the alu instance
opt -full       # constant propagation ← this is the PSIM equivalent
techmap         # map $add etc. to gate primitives
opt -full
aigmap          # everything → AND + inverter
write_aiger -ascii -symbols aig/${OP}.aag
```

**Verification that extraction worked** is the AIGER header, `aag M I L O A`:

| op | M | I | L | O | AND gates |
|---|---|---|---|---|---|
| AND | 96 | 64 | 0 | 32 | 32 |
| XOR | 160 | 64 | 0 | 32 | 96 |
| ADD | 410 | 64 | 0 | 32 | 346 |

`I = 64` means only `a` and `b` survive — the 4 opcode inputs are gone, so constant
propagation fully absorbed them. `L = 0` confirms the design is purely combinational.
Gate counts are structurally sensible: 1 gate/bit for AND, 3/bit for XOR (standard AIG
XOR), ~10.8/bit for ADD (ripple-carry full adders).

### Step 3 — Build BDDs under a controlled order

`scripts/profile2.py` reads the AIGER file, determines the true input → BDD-variable
mapping, declares variables in **interleaved** order, then builds one BDD per output bit
in a shared manager.

---

## Results

### Node counts vs Table III

| Instruction | Table III | This work | Status |
|---|---|---|---|
| AND | 97 | **97** | exact |
| XOR | 161 | **161** | exact |
| ADD | 1327 | 1553 | +17% |
| OR | 97 | — | not yet run |
| SUB | 1415 | — | not yet run |
| SLL | 1632 | — | not yet run |
| SRL | 1431 | — | not yet run |
| SRA | 1396 | — | not yet run |
| SLT | 992 | — | not yet run |
| SLTU | 809 | — | not yet run |

### The ADD result (the substantive finding)

Per-output-bit BDD sizes under interleaved ordering:

```
bit  0 :  3
bit  1 :  5
bit  2 :  8
bit  3 : 11
bit  4 : 14
...
bit 31 : 95

diffs: [2, 3, 3, 3, ..., 3]
sum:   1553
```

Exact closed form:

```
size(bit 0) = 3
size(bit k) = 3k + 2      for k ≥ 1
```

**Perfectly linear growth per output bit.** Summing over 32 bits gives Θ(n²) total —
which is precisely the Addition-group bound the paper claims. *The complexity result
reproduces, even though the absolute constant does not.*

The +3 nodes/bit increment is the ripple-carry signature: each successive output bit
depends on one additional carry variable, and under interleaved ordering that costs a
constant number of nodes. Yosys inferred a ripple-carry adder from behavioural `a + b`,
matching the paper's stated RCA reference model — which is why the growth *shape* agrees
even where the constant does not.

---

## The variable-ordering problem

This turned out to be the dominant engineering issue, and it is worth understanding
before touching the code.

BDD size depends catastrophically on the order in which variables are tested.

- **Interleaved** (`a0, b0, a1, b1, ...`): ADD builds in 0.5 s, 1553 nodes.
- **Grouped** (`a0..a31, b0..b31`): ADD did not terminate. It exhausted 7 GB of RAM and
  was killed by the OOM killer, taking WSL down with it.

Same circuit. Same function. Same tool. Only the order changed.

The intuition: under grouped ordering the BDD must "remember" all 32 bits of `a` before
it sees any bit of `b`, which requires exponentially many distinct sub-graphs. Under
interleaved ordering it only ever needs to remember one carry bit.

This is not incidental to the paper — it *is* the paper's mechanism. Their claim that
verification is polynomial depends entirely on choosing a good order, and they note that
their RMG deliberately generates the same ordering as SYMSIM so the two BDDs are
comparable.

---

## Open discrepancies

Documented rather than resolved. These are findings, not failures.

### 1. The node-accounting convention is unspecified

Four candidate metrics were measured. Only `len(manager)` (total nodes in the shared BDD
manager) reproduces 97 and 161.

But that metric decomposes as:

```
AND:  64 vars + 32 AIG gates + 1 terminal = 97
XOR:  64 vars + 96 AIG gates + 1 terminal = 161
```

It equals *(#variables + #AIG gates + 1)* — i.e. it tracks **gate count**, not BDD
structure. For bitwise operations the two coincide, because each output bit is
independent and there is no sharing. For ADD they diverge badly: the manager holds all
346 carry-chain intermediates, giving ≈6500.

**So the exact AND/XOR matches may be coincidental.** No metric tested yields 1327.

Metrics measured, for the record:

| Metric | AND | XOR | ADD |
|---|---|---|---|
| `len(manager)` — all nodes in manager | 97 | 161 | ~6500 (unstable) |
| Sum of per-output BDD sizes | 96 | 96 | 1553 |
| Union of nodes reachable from the 32 roots | 65 | 65 | — |
| Max single output | 3 | 3 | 95 |

The union metric gives 65 for both AND and XOR, proving it is insensitive to function
complexity — it just counts 64 variable nodes + 1 terminal. Discarded.

### 2. 1327 admits no clean closed form

Under any per-bit model fitted here, 1327 does not decompose the way 97 and 161 do. This
suggests either a different accounting convention or a different adder realisation
upstream in their flow.

### 3. Methodological finding — BDD counts are unreproducible without a stated order

`py-aiger` iterates its input set in hash order, which is **seed-dependent across
processes**. Identical code produced manager counts of 6036 and 6585 on consecutive runs.
Under an unlucky seed, the ADD build exploded.

Runs are now pinned with `PYTHONHASHSEED=0` and an explicitly declared interleaved order.

**Consequence:** any published BDD node count that does not state its variable order is
not reproducible. This applies to Table III, and to a large fraction of the BDD
literature.

---

## Repository layout

```
project6-pfv/
├── README.md              this file
├── RESULTS.md             condensed results log
├── rtl/
│   ├── alu.sv             the RV32I ALU under verification
│   └── alu_pinned.sv      opcode-pinned wrappers (one module per instruction)
├── aig/
│   ├── and.aag            extracted AIGER sub-circuits
│   ├── xor.aag
│   └── add.aag
└── scripts/
    ├── extract.sh         Yosys extraction (PSIM equivalent)
    ├── profile2.py        per-bit BDD growth profile  ← the important one
    └── bddcount7.py       aggregate node-count metrics
```

---

## Reproducing

### Environment

Yosys comes from the LibreLane nix-shell; the BDD tooling lives in a separate venv.
**They are deliberately not in the same environment** — Yosys writes an AIGER file to
disk and Python reads it back, so they never need to share an interpreter.

```bash
# one-time venv setup
python3 -m venv ~/pfv-rv32i/.venv
source ~/pfv-rv32i/.venv/bin/activate
pip install "setuptools<81" wheel
pip install "dd==0.5.7" "py-aiger-bdd==0.2.1" py-aiger
```

Version pinning matters: `py-aiger-bdd` 3.x requires `dd==0.5.7`, whose `setup.py`
imports the removed `pkg_resources`. The combination above installs from wheels with no
compilation.

### Running

```bash
# 1. Extract (needs Yosys, so run inside the nix-shell)
cd ~/librelane && nix-shell --run "~/pfv-rv32i/extract.sh add"

# 2. Sanity-check the extraction
head -1 ~/pfv-rv32i/aig/add.aag        # expect: aag 410 64 0 32 346

# 3. Profile (needs the venv)
cd ~/pfv-rv32i && source .venv/bin/activate && python3 profile2.py add
```

Expected output ends with:

```
sum : 1553
diffs: [2, 3, 3, 3, ..., 3]
```

### Gotchas

- The venv **must** be active. Without it, the system Python may pick up different
  package versions and produce silently different results.
- `profile2.py` re-executes itself with `PYTHONHASHSEED=0`. Do not remove this.
- A 5 GB `RLIMIT_AS` is set so a bad variable order fails with `MemoryError` in seconds
  instead of thrashing the machine.

---

## Remaining work

In rough priority order:

1. **Reference Model Generator.** Build an independent BDD per instruction group
   (logic / shift / add / sub) directly from the RV32I ISA definition, then check
   identity against the circuit BDD in a shared manager. *This is what turns the project
   from "BDD construction" into "equivalence checking."*
2. **The other seven opcodes.** Mechanical: add wrappers to `alu_pinned.sv`, run the
   same two commands. SUB and the shift group are the interesting ones — the paper
   reports SLL as the largest BDD of all (1632), attributed to modelling a generic
   shifter, so a divergence there would be an architectural finding.
3. **Resolve the accounting convention**, or establish that it cannot be resolved from
   the published description. Either outcome is publishable as a reproducibility note.
4. **Timing comparison** against their PSIM/PFV columns, which would require building
   `dd.cudd` from source for a fair comparison.

---

## References

1. L. Weingarten, K. Datta, A. Kole, R. Drechsler, "Complete and Efficient Verification
   for a RISC-V Processor using Formal Verification," *DATE*, 2024.
2. L. Weingarten, K. Datta, R. Drechsler, "PolyMiR: Polynomial Formal Verification of the
   MicroRV32 Processor," *NANOARCH*, 2023. — *source of Table III*
3. L. Weingarten, A. Mahzoon, M. Goli, R. Drechsler, "Polynomial Formal Verification of
   Processor: A RISC-V Case Study," *ISQED*, 2023.
4. R. Drechsler, A. Mahzoon, "Polynomial Formal Verification: Ensuring Correctness under
   Resource Constraints," *ICCAD*, 2022.
5. S. Ahmadi-Pour, V. Herdt, R. Drechsler, "The MicroRV32 framework," *JSA*, 2022.
6. F. Somenzi, "CUDD: CU Decision Diagram Package."
7. C. Wolf, "Yosys Open SYnthesis Suite."

---

## License

Apache-2.0, consistent with the rest of the portfolio.

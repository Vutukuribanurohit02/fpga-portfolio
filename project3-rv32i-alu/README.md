# Project 3 — RV32I ALU, Formally Verified

Status: ✅ All 11 properties formally proven · ✅ Functional simulation passing

A combinational RV32I Arithmetic Logic Unit, with every operation proven
bit-exact against its mathematical definition using SymbiYosys — not
sampled with test vectors, but proven correct for the entire input space.

---

## Why this project

The ALU is the first functional block of the from-scratch RISC-V core this
portfolio is building toward. It's also the cleanest possible target for
formal verification: purely combinational, no clock, no state, no timing
complexity to fight — which makes it the right place to build real fluency
with property-based proof before tackling something with sequential state
(the CPU in Project 4).

---

## Architecture
Ten operations, selected by a 4-bit `alu_op`: `ADD`, `SUB`, `AND`, `OR`,
`XOR`, `SLT` (signed less-than), `SLTU` (unsigned less-than), `SLL`
(shift left), `SRL` (shift right logical, zero-fill), `SRA` (shift right
arithmetic, sign-extend). A `zero` flag output reflects whether `result`
equals zero — useful later for branch comparisons in the CPU.

The ALU takes a clean 4-bit opcode rather than raw `funct3`/`funct7`
instruction bits directly, keeping it instruction-format-agnostic; the
CPU's decoder (Project 4) will translate the actual RV32I encoding into
this selector.

---

## Formal verification

**Toolchain:** Yosys + SymbiYosys + Boolector, run under WSL2/Ubuntu.

**What's proven:** every one of the 10 operations, plus the zero flag —
**11 properties total, all proven, zero exceptions.** Each property
asserts `result` equals the operation's independent mathematical
definition (not a restatement of the RTL's own case statement, which
would prove nothing) for every reachable input.

| Property | Status |
|---|---|
| ADD, SUB, AND, OR, XOR | ✅ Proven |
| SLT (signed), SLTU (unsigned) | ✅ Proven |
| SLL, SRL | ✅ Proven |
| SRA | ✅ Proven (see note below) |
| Zero flag correctness | ✅ Proven |

**Run it yourself:**
```bash
cd formal
sby -f alu.sby
```

### A false counterexample, and how it was resolved

The SRA (arithmetic right shift) property initially failed formal
verification — SymbiYosys reported a counterexample with specific `a`,
`b` values where the assertion `result == ($signed(a) >>> shamt)`
supposedly didn't hold.

Before assuming a design bug, the counterexample's exact input values
were extracted from SymbiYosys's own witness trace and fed directly into
a standalone Icarus Verilog simulation of the RTL. **The RTL produced the
mathematically correct result** — matching a value independently computed
by hand. Netlist inspection (`yosys ... stat`) further confirmed the DUT
and the formal property module synthesized to structurally identical
single-cell `$sshr` logic — ruling out a width mismatch or duplicated-logic
explanation.

That left one conclusion: this specific Boolector/SymbiYosys version's SMT
translation of `$signed(a) >>> shamt` — arithmetic right shift with a
*variable* (non-constant) shift amount and a signed cast — was producing
a false counterexample, not the RTL.

The fix wasn't to weaken or drop the property (as some properties in
Project 2 had to be, for genuinely unresolved tooling gaps). Instead, the
assertion was rewritten to prove the *exact same mathematical claim*
through a structurally different, solver-friendlier expression:
sign-extend `a` to double width, shift logically, then truncate back —
mathematically equivalent to arithmetic right shift, but avoiding the
specific `>>> `-with-variable-shift-amount pattern that tripped up the
solver. Re-run against this reformulated property, verification passed
cleanly. **All 11 properties are proven with zero exceptions** — a
stronger final result than Project 2's formal proof, where two properties
had to be documented as tooling-limited and left unproven.

This is worth calling out on its own: a formal tool reporting a failure
doesn't automatically mean the design is wrong. Confirming against an
independent ground truth (direct simulation, and in this case also
netlist inspection) before touching the RTL is what separates a real bug
fix from chasing a tooling artifact.

---

## Functional simulation

Self-checking testbench (`sim/alu_tb.sv`): 27 directed test vectors
covering edge cases (signed/unsigned overflow wraparound, shift-by-zero,
shift-by-31, shift-amount masking at 32, negative-number signed compare
and shift) plus a 500-iteration randomized sweep checked against an
independent reference model.

**Result:** 527/527 checks pass, 0 errors.

```bash
cd sim
iverilog -g2012 -o alu_tb.vvp alu_tb.sv ../rtl/alu.sv
vvp alu_tb.vvp
```

---

## Key learnings

- **A failing formal proof isn't automatically a design bug.** SMT
  solvers can mistranslate certain expression patterns (here: signed
  arithmetic shift by a variable amount), and treating every
  counterexample as gospel without independent verification risks
  "fixing" correct RTL to satisfy a broken check.
- **Independent ground truth matters.** Extracting the exact
  counterexample inputs and re-running them through a completely separate
  tool (Icarus Verilog simulation, plus manual hand computation) was what
  made it possible to distinguish a real bug from a tooling artifact with
  confidence, rather than guessing.
- **The fix targets the proof, not the design, when the design is
  right.** Rewriting an assertion to a mathematically equivalent but
  structurally different form is a legitimate, principled way to route
  around a solver limitation — very different from weakening what's
  actually being proven.

---

## Toolchain

| Tool | Purpose |
|---|---|
| Icarus Verilog | Functional simulation |
| Yosys | RTL elaboration / synthesis frontend |
| SymbiYosys | Formal verification flow orchestration |
| Boolector | SMT solver backend for BMC |

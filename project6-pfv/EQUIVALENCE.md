# Equivalence Checking — Findings

This closes the gap identified in the original Project 6 write-up: node counting
is a fingerprint, not a proof. The Reference Model Generator and the equivalence
check are now implemented, and all ten ALU operations are proven equivalent to an
independently constructed golden model.

Three results below change how the earlier numbers should be interpreted. Two of
them contradict explanations given in the first version of this project.

---

## 1. What was built

| File | Role |
|---|---|
| `scripts/rmg.py` | Reference Model Generator — golden BDDs from RV32I semantics |
| `scripts/equiv.py` | Equivalence checker with counterexample extraction |
| `scripts/test_rmg.py` | Exhaustive validation of the RMG itself |
| `scripts/gen_test_aig.py` | Stand-in AIG generator, for testing without Yosys |
| `scripts/run_all.sh` | Extract + check all ten opcodes |
| `rtl/alu_pinned.sv` | All ten opcode-pinned wrappers (was three) |

### The reference is deliberately not the same architecture

The RMG builds addition as a **Kogge-Stone parallel-prefix carry network**;
subtraction reuses it as `a + ¬b + 1`; shifts use a **5-stage barrel shifter**.
The circuit under test synthesises from behavioural RTL to a **ripple-carry
chain** and cascaded shift stages.

The two share no structure. If the BDDs come out identical, that is a real
result about the functions, not an artefact of building the same thing twice.

### The RMG is itself validated

A reference model that is silently wrong turns every "EQUIVALENT" into a lie.
`test_rmg.py` builds each operation at width 6 and evaluates it over all 4,096
input assignments, comparing against Python integer arithmetic:

```
  add   PASS   all 4096 assignments
  sub   PASS   all 4096 assignments
  and   PASS   all 4096 assignments
  or    PASS   all 4096 assignments
  xor   PASS   all 4096 assignments
  slt   PASS   all 4096 assignments
  sltu  PASS   all 4096 assignments
  sll   PASS   all 4096 assignments
  srl   PASS   all 4096 assignments
  sra   PASS   all 4096 assignments

RESULT: ALL OPERATIONS VALIDATED
```

---

## 2. Equivalence results

All ten operations, 32-bit, interleaved variable order:

```
EQUIVALENT  ADD  : all 32 output bits match the reference model
EQUIVALENT  SUB  : all 32 output bits match the reference model
EQUIVALENT  AND  : all 32 output bits match the reference model
EQUIVALENT  OR   : all 32 output bits match the reference model
EQUIVALENT  XOR  : all 32 output bits match the reference model
EQUIVALENT  SLT  : all 32 output bits match the reference model
EQUIVALENT  SLTU : all 32 output bits match the reference model
EQUIVALENT  SLL  : all 32 output bits match the reference model
EQUIVALENT  SRL  : all 32 output bits match the reference model
EQUIVALENT  SRA  : all 32 output bits match the reference model
```

Because ROBDDs are canonical, equality of the root nodes *is* equivalence of the
functions over all 2⁶⁴ input combinations. The comparison itself is a pointer
check.

### Fault injection — proving the checker can fail

A passing test that cannot fail proves nothing. `gen_test_aig.py` emits a
deliberately broken adder with the carry into bit 17 inverted:

```
NOT EQUIVALENT  ADD : 1 of 32 output bits differ: [17]
counterexample on bit 17:  a = 0x00000000   b = 0x00000000
```

The counterexample is correct by hand: with `a = b = 0` the true carry into bit
17 is 0, the injected fault inverts it to 1, so `sum[17]` becomes 1 where the
reference gives 0. The checker localises the fault to a single output bit and
produces a concrete failing vector.

---

## 3. Correction: adder architecture cannot explain the ADD discrepancy

**The earlier write-up attributed the 1553-vs-1327 gap partly to adder
architecture. That explanation is wrong, and provably so.**

An ROBDD is canonical: for a fixed variable order, a Boolean function has exactly
one ROBDD. Two circuits computing the same function therefore have the *same*
BDD, whatever their internal structure.

Measured directly — the prefix-carry reference and the ripple-carry circuit:

| | per-bit profile | closed form | sum |
|---|---|---|---|
| Circuit (ripple-carry) | 3, 5, 8, 11, … 95 | `3k + 2` | 1553 |
| Reference (Kogge-Stone prefix) | 3, 5, 8, 11, … 95 | `3k + 2` | 1553 |

Byte-identical. Choosing a carry-lookahead adder, a carry-select adder, or any
other correct implementation would not move the number by one node.

So the gap to the paper's 1327 is **not** architectural. It is a difference in
what is being counted, or in the scope of the extracted function.

This is a better finding than the original claim, because it is a proof rather
than a hypothesis — and it demonstrates canonicity doing real work.

---

## 4. Correction: the paper's counts are construction-path dependent

The original write-up flagged that the exact AND=97 and XOR=161 matches "may be
coincidental." They are — and the evidence is now decisive.

As *functions*, 32-bit bitwise AND and 32-bit bitwise XOR have **identical BDD
sizes**. Each output bit depends on exactly two variables, and both `a∧b` and
`a⊕b` reduce to a 3-node ROBDD:

```
and: per-bit 3   sum 96   manager 97
xor: per-bit 3   sum 96   manager 97      ← built directly from the reference
```

But building the *same* XOR function by traversing its AIG gives:

```
xor: manager 161                          ← built from the 96-gate AIG
```

Same function, same variable order, two different "node counts" — 97 and 161 —
depending only on how the BDD was constructed. The 161 counts the 96 intermediate
BDDs created while walking the AIG's gates.

**Therefore `manager nodes` measures the construction path, not the function.**
Any metric that reproduces the paper's 97-vs-161 distinction is measuring the
same artefact, since at the function level there is no distinction to measure.

---

## 5. Full comparison against Table III

Circuit BDDs, interleaved order, all ten operations:

| op | Table III | sum-per-output | manager | closest metric |
|---|---|---|---|---|
| AND | 97 | 96 | **97** | manager (exact) |
| OR | 97 | 96 | **97** | manager (exact) |
| XOR | 161 | 96 | **161** | manager (exact) |
| SLL | 1632 | **1640** | 1533 | sum (+0.5%) |
| SRL | 1431 | **1432** | 1275 | sum (+1 node) |
| SRA | 1396 | **1401** | 1369 | sum (+0.4%) |
| ADD | 1327 | 1553 | 5897 | none (+17%) |
| SUB | 1415 | 1553 | 5897 | none (+10%) |
| SLT | 992 | 127 | 3353 | none |
| SLTU | 809 | 127 | 3075 | none |

Reading this honestly:

- **The shift group reproduces.** SRL is one node off; SLL and SRA are within
  half a percent. That is a genuine reproduction of three published values, and
  it is the strongest evidence yet that the extraction and ordering are faithful.
- **The logic group reproduces only under a metric now known to be an artefact.**
- **No single metric fits all three groups.** Logic matches under `manager`,
  shifts match under `sum`, and arithmetic matches under neither. A consistent
  counting convention would not behave this way.
- **SLT/SLTU differ structurally.** My ALU produces 31 constant-zero bits plus
  one comparison bit, so the sum is small. The paper's 992 and 809 suggest their
  Execute unit keeps the full subtractor result live. That is a genuine
  architectural difference and is reportable as such.

### What this supports

The reproducibility critique from the original write-up now rests on three
independent legs rather than one:

1. Node counts are meaningless without a stated variable order (established
   earlier — a bad order took the same circuit from 0.5 s to OOM).
2. Node counts are meaningless without a stated counting convention (no single
   metric fits all groups).
3. Even with both fixed, counts depend on the construction path, so they are not
   a property of the verified function at all (AND vs XOR, proven above).

---

## 6. Running it

```bash
# extract all ten sub-circuits (needs Yosys)
cd ~/librelane && nix-shell --run "~/pfv-rv32i/scripts/run_all.sh extract"

# validate the reference model, then check everything (needs the venv)
cd ~/pfv-rv32i && source .venv/bin/activate
python3 scripts/test_rmg.py 6
./scripts/run_all.sh check
```

Single operation, with detail:

```bash
python3 scripts/equiv.py add
```

To exercise the flow without Yosys — generates stand-in AIGs, including the
fault-injected adder:

```bash
python3 scripts/gen_test_aig.py 32
python3 scripts/equiv.py add
```

---

## 7. What is still open

- **The ADD/SUB constant.** 1553 vs 1327 is unexplained. It is now known *not* to
  be architecture. Candidates: a different extraction scope in their Execute
  unit, or a counting convention that is neither of the two tested here.
- **SLT/SLTU structural difference.** Worth confirming against the MicroRV32
  source, which is public, rather than inferring from node counts.
- **Timing comparison.** Their PSIM/PFV millisecond figures would need `dd.cudd`
  built from source to compare fairly.

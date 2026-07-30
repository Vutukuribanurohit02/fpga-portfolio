# PFV Reimplementation - Weingarten et al. (DATE 2024) / PolyMiR (NANOARCH 2023)

Reimplementation of the combinational per-instruction BDD equivalence-checking
methodology (Table III) against my RV32I ALU.

## Toolchain substitution

| Paper (in-house C++) | This work |
|---|---|
| Yosys + ABC -> AIG | Yosys 0.62, `aigmap` + `write_aiger` |
| PSIM (ternary sim, per-instruction extraction) | Yosys const-propagation with opcode pinned |
| SYMSIM (AIG -> BDD via CUDD) | py-aiger 8.1.0 + py-aiger-bdd 0.2.1 + dd 0.5.7 |

## Extraction verified

Opcode-pinned wrappers instantiate the ALU with `alu_op` tied to a constant.
AIGER headers confirm the opcode is fully propagated away (`aag M I L O A`):

| op | M | I | L | O | AND gates |
|---|---|---|---|---|---|
| AND | 96 | 64 | 0 | 32 | 32 |
| XOR | 160 | 64 | 0 | 32 | 96 |
| ADD | 410 | 64 | 0 | 32 | 346 |

I=64 (a, b only), L=0 (purely combinational).

## Results vs Table III

| Instr | Paper | This work | Note |
|---|---|---|---|
| AND | 97 | 97 | exact |
| XOR | 161 | 161 | exact |
| ADD | 1327 | 1553 | +17%, see below |

## ADD: per-bit growth (the substantive result)

Under interleaved variable ordering (a[0], b[0], a[1], b[1], ...):

    size(bit 0) = 3
    size(bit k) = 3k + 2   for k >= 1
    diffs = [2, 3, 3, ..., 3]   (constant)
    sum   = 1553

Exactly linear per output bit -> total is O(n^2), which is the Addition-group
bound the paper claims. The complexity result reproduces even though the
absolute constant does not.

Per-bit growth of +3 nodes is the ripple-carry signature: each successive bit
adds one carry variable to the cofactor structure at constant cost. Yosys
inferred a ripple-carry adder from behavioural `a + b`, matching the paper's
stated RCA reference model.

## Open discrepancies (not resolved)

1. **Node-accounting convention is unspecified in the paper.** Three candidate
   metrics were measured. Only `len(manager)` reproduces 97/161 - but it equals
   (#vars + #AIG gates + 1) in both cases, i.e. it tracks gate count, not BDD
   structure, so it cannot be the general convention. For ADD it reports ~6.5k
   because it includes all 346 carry-chain intermediates. No metric tested
   yields 1327.
2. 1327 admits no clean closed form under any per-bit model fitted here,
   suggesting a different accounting or adder realisation upstream.

## Methodological finding: BDD counts are unreproducible without a stated order

`py-aiger`'s input iteration is set-ordered and therefore hash-seed dependent.
Identical code produced manager counts of 6036 and 6585 on different runs, and
under grouped (non-interleaved) ordering the ADD build exhausted 7 GB and was
OOM-killed. Runs are pinned with `PYTHONHASHSEED=0` and an explicitly declared
interleaved order.

Consequence: any published BDD node count without an accompanying variable
order is not reproducible. This applies to Table III.

## Reproduce

    cd ~/librelane && nix-shell --run "~/pfv-rv32i/extract.sh <op>"
    cd ~/pfv-rv32i && source .venv/bin/activate && python3 profile2.py <op>

Confirmed ops: and, xor, add. Remaining seven opcodes are mechanical.

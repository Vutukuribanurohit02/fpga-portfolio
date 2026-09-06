#!/usr/bin/env python3
"""
fuzz.py — differential testing with automatic counterexample shrinking.

Generates random RV32I instruction sequences, injects them into the Verilator
harness and into the Python reference model, diffs the two RVFI traces
field-by-field, and — on a mismatch — shrinks the sequence to a minimal one
that still fails.

The shrinking is the part that matters. A 500-instruction mismatch tells you
almost nothing; a 3-instruction one tells you what the bug is.

Usage:
    ./fuzz.py                       200 sequences of 30 instructions
    ./fuzz.py -n 1000 -l 50         1000 sequences of 50
    ./fuzz.py --seed 42             reproducible
    ./fuzz.py --replay fail.hex     re-run one sequence and show the diff
"""

import argparse
import json
import random
import subprocess
import sys
import tempfile
import os

import model

SIM = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "obj_dir", "dii_sim")

# Fields that only carry meaning under certain conditions. mem_addr is driven
# from the ALU result on every instruction, and mem_rdata reflects whatever the
# bus returned, so both are noise unless a mask is set.
def meaningful(rec):
    out = dict(rec)
    if not rec["mem_rmask"] and not rec["mem_wmask"]:
        for f in ("mem_addr", "mem_rdata", "mem_wdata"):
            out.pop(f, None)
    if not rec["mem_wmask"]:
        out.pop("mem_wdata", None)
    if not rec["mem_rmask"]:
        out.pop("mem_rdata", None)
    return out


# ------------------------------------------------------------------ generator
R_OPS  = [(0x0, 0x00), (0x0, 0x20), (0x1, 0x00), (0x2, 0x00), (0x3, 0x00),
          (0x4, 0x00), (0x5, 0x00), (0x5, 0x20), (0x6, 0x00), (0x7, 0x00)]
I_OPS  = [0x0, 0x2, 0x3, 0x4, 0x6, 0x7]
LOADS  = [0x0, 0x1, 0x2, 0x4, 0x5]
STORES = [0x0, 0x1, 0x2]
BRANCH = [0x0, 0x1, 0x4, 0x5, 0x6, 0x7]

# Immediates drawn from a set of interesting values rather than uniformly —
# sign boundaries and small magnitudes find bugs that uniform random misses.
INTERESTING = [0, 1, 2, 3, 4, -1, -2, -4, 0x7FF, -0x800, 0x555, -0x556]


def rnd_reg(rng):
    # x0 included deliberately: writes to it must be discarded, reads must be 0.
    # Biased toward x1-x11, which prelude() seeds with wide values. Uniform
    # selection across all 32 leaves most operands small and non-negative, so
    # sign-sensitive operations never diverge from their unsigned counterparts.
    if rng.random() < 0.75:
        return rng.randrange(1, 12)
    return rng.randrange(0, 32)


def rnd_imm(rng, bits=12):
    if rng.random() < 0.6:
        v = rng.choice(INTERESTING)
    else:
        v = rng.randrange(-(1 << (bits - 1)), 1 << (bits - 1))
    return v & ((1 << bits) - 1)


def gen_insn(rng):
    kind = rng.choices(
        ["r", "i", "load", "store", "branch", "lui", "auipc", "jal", "jalr"],
        weights=[30, 25, 10, 10, 15, 3, 3, 2, 2])[0]
    rd, rs1, rs2 = rnd_reg(rng), rnd_reg(rng), rnd_reg(rng)

    if kind == "r":
        f3, f7 = rng.choice(R_OPS)
        return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | 0x33
    if kind == "i":
        f3 = rng.choice(I_OPS)
        return (rnd_imm(rng) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | 0x13
    if kind == "load":
        f3 = rng.choice(LOADS)
        return (rnd_imm(rng) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | 0x03
    if kind == "store":
        f3 = rng.choice(STORES)
        imm = rnd_imm(rng)
        return (((imm >> 5) & 0x7F) << 25) | (rs2 << 20) | (rs1 << 15) \
             | (f3 << 12) | ((imm & 0x1F) << 7) | 0x23
    if kind == "branch":
        f3 = rng.choice(BRANCH)
        imm = rnd_imm(rng, 13) & ~1
        return (((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) \
             | (rs2 << 20) | (rs1 << 15) | (f3 << 12) \
             | (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 1) << 7) | 0x63
    if kind == "lui":
        return (rng.randrange(0, 1 << 20) << 12) | (rd << 7) | 0x37
    if kind == "auipc":
        return (rng.randrange(0, 1 << 20) << 12) | (rd << 7) | 0x17
    if kind == "jal":
        imm = rnd_imm(rng, 21) & ~1
        return (((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3FF) << 21) \
             | (((imm >> 11) & 1) << 20) | (((imm >> 12) & 0xFF) << 12) \
             | (rd << 7) | 0x6F
    return (rnd_imm(rng) << 20) | (rs1 << 15) | (rd << 7) | 0x67


PRELUDE_VALUES = [0x80000000, 0xFFFFFFFF, 0x7FFFFFFF, 0x80000001,
                  0xDEADBEEF, 0x00000001, 0xFFFF0000, 0x0000FFFF]


def prelude(rng):
    """Seed registers with wide values before the random body.

    Without this every register holds a small non-negative number, so
    sign-sensitive operations (SRA vs SRL, SLT vs SLTU, BLT vs BLTU) never
    diverge and the fuzzer exercises them syntactically without ever reaching
    the behaviour that distinguishes them. Measured: zero SRA instructions
    with a negative operand across 6,000 generated instructions.

    LUI sets the upper 20 bits, ADDI fills the lower 12.
    """
    out = []
    for r in range(1, 12):
        v = rng.choice(PRELUDE_VALUES) if rng.random() < 0.7 \
            else rng.randrange(0, 1 << 32)
        hi, lo = (v >> 12) & 0xFFFFF, v & 0xFFF
        if lo & 0x800:                      # ADDI sign-extends; pre-compensate
            hi = (hi + 1) & 0xFFFFF
        out.append((hi << 12) | (r << 7) | 0x37)                 # lui  r, hi
        out.append((lo << 20) | (r << 15) | (r << 7) | 0x13)     # addi r, r, lo
    return out


def gen_seq(rng, n):
    return prelude(rng) + [gen_insn(rng) for _ in range(n)]


# --------------------------------------------------------------------- runner
def run_dut(seq):
    with tempfile.NamedTemporaryFile("w", suffix=".hex", delete=False) as f:
        for i in seq:
            f.write("%08x\n" % i)
        path = f.name
    try:
        out = subprocess.run([SIM, path], capture_output=True, text=True,
                             timeout=60)
        if out.returncode != 0:
            return None, out.stderr.strip()
        return [json.loads(l) for l in out.stdout.splitlines() if l.strip()], None
    finally:
        os.unlink(path)


def compare(seq):
    """Return None if the traces agree, else a description of the first diff."""
    dut, err = run_dut(seq)
    if dut is None:
        return {"kind": "sim-error", "detail": err}
    ref = model.run(seq)

    if len(dut) != len(ref):
        return {"kind": "length", "dut": len(dut), "ref": len(ref)}

    for i, (a, b) in enumerate(zip(dut, ref)):
        ma, mb = meaningful(a), meaningful(b)
        for k in sorted(set(ma) | set(mb)):
            if ma.get(k) != mb.get(k):
                return {"kind": "field", "index": i, "field": k,
                        "dut": ma.get(k), "ref": mb.get(k),
                        "insn": a.get("insn"), "dut_rec": a, "ref_rec": b}
    return None


# ------------------------------------------------------------------- shrinker
def shrink(seq, fails):
    """Delta debugging: repeatedly drop instructions while the failure holds.

    Two passes. The first halves the sequence greedily, which collapses a
    500-instruction case to tens in a few steps. The second removes single
    instructions, which gets to a genuine minimum.
    """
    cur = list(seq)

    chunk = len(cur) // 2
    while chunk >= 1:
        i = 0
        while i < len(cur):
            cand = cur[:i] + cur[i + chunk:]
            if cand and fails(cand):
                cur = cand
            else:
                i += chunk
        chunk //= 2

    i = 0
    while i < len(cur):
        cand = cur[:i] + cur[i + 1:]
        if cand and fails(cand):
            cur = cand
        else:
            i += 1
    return cur


# ----------------------------------------------------------------------- main
def show(seq, diff):
    print("\n--- minimal failing sequence (%d instructions) ---" % len(seq))
    for i in seq:
        print("%08x" % i)
    print("\n--- first divergence ---")
    if diff["kind"] == "field":
        print("instruction #%d  (%s)" % (diff["index"], diff["insn"]))
        print("field    : %s" % diff["field"])
        print("dut      : %s" % diff["dut"])
        print("reference: %s" % diff["ref"])
        print("\ndut  record: %s" % json.dumps(diff["dut_rec"]))
        print("ref  record: %s" % json.dumps(diff["ref_rec"]))
    else:
        print(json.dumps(diff, indent=2))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-n", type=int, default=200, help="sequences to try")
    ap.add_argument("-l", type=int, default=30, help="instructions per sequence")
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--replay", help="re-run one hex file and show the diff")
    args = ap.parse_args()

    if not os.path.exists(SIM):
        print("harness not built — run ./build.sh first", file=sys.stderr)
        return 2

    if args.replay:
        seq = model.read_hex(args.replay)
        d = compare(seq)
        if d is None:
            print("traces agree")
            return 0
        show(seq, d)
        return 1

    seed = args.seed if args.seed is not None else random.randrange(1 << 30)
    rng = random.Random(seed)
    print("seed %d — %d sequences x %d instructions" % (seed, args.n, args.l))

    for k in range(args.n):
        seq = gen_seq(rng, args.l)
        d = compare(seq)
        if d is not None:
            print("\nMISMATCH on sequence %d" % k)
            print("shrinking from %d instructions..." % len(seq))
            small = shrink(seq, lambda s: compare(s) is not None)
            show(small, compare(small))
            with open("fail.hex", "w") as f:
                for i in small:
                    f.write("%08x\n" % i)
            print("\nwritten to fail.hex — replay with ./fuzz.py --replay fail.hex")
            return 1
        if (k + 1) % 25 == 0:
            print("  %d/%d clean" % (k + 1, args.n))

    print("\n%d sequences, no mismatches" % args.n)
    return 0


if __name__ == "__main__":
    sys.exit(main())

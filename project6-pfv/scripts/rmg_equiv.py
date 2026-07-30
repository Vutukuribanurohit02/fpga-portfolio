#!/usr/bin/env python3
"""
rmg_equiv.py -- Reference Model Generator + BDD equivalence checking.

This is the piece the earlier scripts were missing. Instead of only building a
BDD from the extracted circuit and counting its nodes, this builds a SECOND BDD
independently from the RV32I instruction semantics, and checks that the two are
the same function.

Because ROBDDs are canonical under a fixed variable order, "same function" is
decidable by structural identity inside one shared manager. If the two BDDs are
the same node, the circuit implements the specification for all 2^64 input
combinations -- a complete proof, not a sample.

This mirrors the RMG component of the Weingarten et al. / PolyMiR flow, which
the paper describes but never released.

Usage:
    python3 rmg_equiv.py add
    python3 rmg_equiv.py all

Requires an extracted AIGER file at ../aig/<op>.aag (see extract.sh).
"""

import os
import sys

# Pin hash seed BEFORE importing anything that iterates sets. py-aiger's input
# iteration order is hash-dependent, which silently changes the variable order
# and therefore the BDD size. Re-exec once to guarantee determinism.
if os.environ.get("PYTHONHASHSEED") != "0":
    os.environ["PYTHONHASHSEED"] = "0"
    os.execv(sys.executable, [sys.executable] + sys.argv)

import re
import time
import resource

import aiger
import aiger_bdd
from dd import autoref

# A bad variable order can consume unbounded memory. Fail fast instead.
resource.setrlimit(resource.RLIMIT_AS, (5 * 1024 ** 3, 5 * 1024 ** 3))

WIDTH = 32
HERE = os.path.dirname(os.path.abspath(__file__))
AIG_DIR = os.path.join(HERE, "..", "aig")

OPS = ["add", "sub", "and", "or", "xor", "slt", "sltu", "sll", "srl", "sra"]

# Published Table III counts (PolyMiR NANOARCH 2023, reproduced in DATE 2024).
TABLE_III = {
    "add": 1327, "sub": 1415, "and": 97, "or": 97, "xor": 161,
    "slt": 992, "sltu": 809, "sll": 1632, "srl": 1431, "sra": 1396,
}


# --------------------------------------------------------------------------
# Reference models -- built from the ISA definition, NOT from the circuit.
#
# Each returns a list of 32 BDDs, one per result bit, LSB first. They are
# written the way the specification reads, deliberately not mirroring the RTL:
# an independent construction is the whole point of a reference model.
# --------------------------------------------------------------------------

def ref_and(a, b, mgr):
    return [a[i] & b[i] for i in range(WIDTH)]


def ref_or(a, b, mgr):
    return [a[i] | b[i] for i in range(WIDTH)]


def ref_xor(a, b, mgr):
    return [a[i] ^ b[i] for i in range(WIDTH)]


def _ripple_add(a, b, carry_in, mgr):
    """Textbook ripple-carry adder. Returns (sum_bits, carry_out)."""
    out = []
    c = carry_in
    for i in range(WIDTH):
        out.append(a[i] ^ b[i] ^ c)
        # majority(a, b, c)
        c = (a[i] & b[i]) | (a[i] & c) | (b[i] & c)
    return out, c


def ref_add(a, b, mgr):
    s, _ = _ripple_add(a, b, mgr.false, mgr)
    return s


def ref_sub(a, b, mgr):
    # Two's complement: a - b == a + ~b + 1
    nb = [~x for x in b]
    s, _ = _ripple_add(a, nb, mgr.true, mgr)
    return s


def _ult(a, b, mgr):
    """Unsigned a < b, LSB to MSB. lt = (~a & b) | ((a == b) & lt_prev)."""
    lt = mgr.false
    for i in range(WIDTH):
        eq = ~(a[i] ^ b[i])
        lt = (~a[i] & b[i]) | (eq & lt)
    return lt


def _slt(a, b, mgr):
    """Signed a < b. Identical to unsigned below the sign bit; the sign bit's
    contribution is inverted because it carries negative weight."""
    lt = mgr.false
    for i in range(WIDTH - 1):
        eq = ~(a[i] ^ b[i])
        lt = (~a[i] & b[i]) | (eq & lt)
    i = WIDTH - 1
    eq = ~(a[i] ^ b[i])
    return (a[i] & ~b[i]) | (eq & lt)


def ref_slt(a, b, mgr):
    bit = _slt(a, b, mgr)
    return [bit] + [mgr.false] * (WIDTH - 1)


def ref_sltu(a, b, mgr):
    bit = _ult(a, b, mgr)
    return [bit] + [mgr.false] * (WIDTH - 1)


def _barrel(a, shamt, mgr, direction, fill):
    """Barrel shifter: 5 stages, stage k shifts by 2^k when shamt[k] is set.
    `fill` supplies bits shifted in (constant false, or the sign bit for SRA)."""
    cur = list(a)
    for k in range(5):
        dist = 1 << k
        nxt = []
        for i in range(WIDTH):
            if direction == "left":
                src = cur[i - dist] if i - dist >= 0 else fill
            else:
                src = cur[i + dist] if i + dist < WIDTH else fill
            # ite(shamt[k], shifted, unshifted)
            nxt.append((shamt[k] & src) | (~shamt[k] & cur[i]))
        cur = nxt
    return cur


def ref_sll(a, b, mgr):
    return _barrel(a, b[:5], mgr, "left", mgr.false)


def ref_srl(a, b, mgr):
    return _barrel(a, b[:5], mgr, "right", mgr.false)


def ref_sra(a, b, mgr):
    # Arithmetic shift fills with the sign bit.
    return _barrel(a, b[:5], mgr, "right", a[WIDTH - 1])


REFERENCE = {
    "add": ref_add, "sub": ref_sub, "and": ref_and, "or": ref_or,
    "xor": ref_xor, "slt": ref_slt, "sltu": ref_sltu,
    "sll": ref_sll, "srl": ref_srl, "sra": ref_sra,
}


# --------------------------------------------------------------------------
# Plumbing
# --------------------------------------------------------------------------

def order_key(name):
    """Interleaved order: a[0], b[0], a[1], b[1], ...  Grouping all of `a`
    above all of `b` makes the adder BDD exponential."""
    m = re.match(r"([ab])\[(\d+)\]", name) or re.match(r"([ab])(\d+)", name)
    return (int(m.group(2)), 0 if m.group(1) == "a" else 1)


def bit_index(name):
    return int(re.search(r"(\d+)", name).group(1))


def check(op, verbose=True):
    path = os.path.join(AIG_DIR, op + ".aag")
    if not os.path.isfile(path):
        return {"op": op, "status": "MISSING", "note": "no " + op + ".aag"}

    circ = aiger.load(path)

    # Probe on a throwaway manager purely to read back the real
    # input-name -> BDD-variable mapping. It is arbitrary, never assume it.
    probe = autoref.BDD()
    probe.configure(reordering=True)
    _, _, i2v = aiger_bdd.to_bdd(circ, output=sorted(circ.outputs)[0],
                                 manager=probe)
    del probe

    # Declare the interleaved order up front, then never reorder.
    mgr = autoref.BDD()
    for name in sorted(i2v, key=order_key):
        mgr.declare(i2v[name])

    def var(sig, i):
        return mgr.var(i2v["%s[%d]" % (sig, i)])

    a = [var("a", i) for i in range(WIDTH)]
    b = [var("b", i) for i in range(WIDTH)]

    t0 = time.time()
    reference = REFERENCE[op](a, b, mgr)
    t_ref = time.time() - t0

    t0 = time.time()
    circuit = {}
    for out in circ.outputs:
        u, _, _ = aiger_bdd.to_bdd(circ, output=out, manager=mgr)
        circuit[bit_index(out)] = u
    t_circ = time.time() - t0

    # ---- the equivalence check -------------------------------------------
    # Canonicity: in a shared manager under one fixed order, two BDDs denote
    # the same function iff they are the same node.
    mismatches = [i for i in range(WIDTH) if circuit[i] != reference[i]]

    result = {
        "op": op,
        "status": "PASS" if not mismatches else "FAIL",
        "mismatches": mismatches,
        "nodes": len(mgr),
        "sum_per_output": sum(len(u) for u in circuit.values()),
        "max_per_output": max(len(u) for u in circuit.values()),
        "t_ref": t_ref,
        "t_circ": t_circ,
        "published": TABLE_III.get(op),
    }

    if verbose:
        print("=" * 62)
        print("  %s" % op.upper())
        print("=" * 62)
        print("  reference model built : %.3f s" % t_ref)
        print("  circuit BDDs built    : %.3f s" % t_circ)
        print("  manager nodes         : %d" % result["nodes"])
        print("  sum of per-output     : %d" % result["sum_per_output"])
        print("  max single output     : %d" % result["max_per_output"])
        print("  Table III (published) : %s" % result["published"])
        print()
        if not mismatches:
            print("  EQUIVALENT -- all 32 output bits structurally identical")
            print("  to the reference model. Proof covers all 2^64 inputs.")
        else:
            print("  NOT EQUIVALENT -- bits differ: %s" % mismatches)
            # A counterexample is worth far more than a failure message.
            diff = circuit[mismatches[0]] ^ reference[mismatches[0]]
            try:
                assign = mgr.pick(diff)
                inv = {v: k for k, v in i2v.items()}
                named = {inv[k]: v for k, v in assign.items() if k in inv}
                av = sum(1 << i for i in range(WIDTH)
                         if named.get("a[%d]" % i))
                bv = sum(1 << i for i in range(WIDTH)
                         if named.get("b[%d]" % i))
                print("  counterexample: a=0x%08X  b=0x%08X  (bit %d)"
                      % (av, bv, mismatches[0]))
            except Exception as exc:
                print("  (could not extract counterexample: %s)" % exc)
        print()

    # Release roots so the manager can be torn down without complaint.
    circuit.clear()
    del reference
    return result


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)

    target = sys.argv[1].lower()
    ops = OPS if target == "all" else [target]

    if target != "all" and target not in REFERENCE:
        print("unknown op %r; known: %s" % (target, ", ".join(OPS)))
        sys.exit(1)

    results = [check(op) for op in ops]

    print("=" * 62)
    print("  SUMMARY")
    print("=" * 62)
    print("  %-6s %-8s %8s %8s  %s"
          % ("op", "equiv", "nodes", "Table III", "delta"))
    print("  " + "-" * 52)
    for r in results:
        if r["status"] == "MISSING":
            print("  %-6s %-8s %s" % (r["op"], "--", r["note"]))
            continue
        pub = r["published"]
        delta = ("%+.1f%%" % (100.0 * (r["nodes"] - pub) / pub)) if pub else "-"
        print("  %-6s %-8s %8d %8s  %s"
              % (r["op"], r["status"], r["nodes"], pub, delta))

    checked = [r for r in results if r["status"] in ("PASS", "FAIL")]
    failed = [r for r in checked if r["status"] == "FAIL"]
    print()
    print("  %d/%d checked, %d equivalent, %d mismatched"
          % (len(checked), len(results), len(checked) - len(failed), len(failed)))
    print()
    print("  Note: the 'nodes' column counts every node in the shared manager,")
    print("  including AIG intermediates. It matches Table III for bitwise ops")
    print("  but not for arithmetic. The equivalence result is independent of")
    print("  this accounting question.")

    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()

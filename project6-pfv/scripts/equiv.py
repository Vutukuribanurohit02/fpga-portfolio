"""
equiv.py -- BDD equivalence checking of an extracted ALU sub-circuit against
the golden reference model.

This is the step the earlier version of Project 6 was missing. Node counts are
a fingerprint; this is a proof.

Method
------
1. Read the opcode-pinned AIGER sub-circuit produced by extract.sh.
2. Read back the real AIGER-input -> BDD-variable mapping (never assume it).
3. Declare variables in interleaved order a[0], b[0], a[1], b[1], ... so the
   adder stays linear rather than exponential.
4. Build the circuit's 32 output BDDs in a shared manager.
5. Build the reference model's 32 output BDDs in the SAME manager with the
   SAME order (rmg.py).
6. Compare root by root. Because ROBDDs are canonical, equality of the roots
   is equivalence of the functions -- a pointer comparison, not a search.
7. On mismatch, extract a concrete counterexample input vector.

Usage
-----
    python3 equiv.py <op>            # e.g. python3 equiv.py add
    python3 equiv.py <op> --quiet
"""

import os
import re
import sys
import time
import resource

# Pin hash randomisation before importing anything that iterates sets.
if os.environ.get("PYTHONHASHSEED") != "0":
    os.environ["PYTHONHASHSEED"] = "0"
    os.execv(sys.executable, [sys.executable] + sys.argv)

import aiger
import aiger_bdd
from dd import autoref

import rmg

MEM_LIMIT_GB = 5
resource.setrlimit(resource.RLIMIT_AS,
                   (MEM_LIMIT_GB * 1024 ** 3, MEM_LIMIT_GB * 1024 ** 3))


def bit_index(name):
    """'a[5]' -> 5, 'b12' -> 12"""
    m = re.match(r'[ab]\[(\d+)\]', name) or re.match(r'[ab](\d+)', name)
    if not m:
        raise ValueError("cannot parse input name %r" % name)
    return int(m.group(1))


def operand(name):
    """'a[5]' -> 'a'"""
    return name[0]


def interleaved_key(name):
    """Sort key giving a[0], b[0], a[1], b[1], ..."""
    return (bit_index(name), 0 if operand(name) == 'a' else 1)


def output_key(name):
    return int(re.search(r'(\d+)', name).group(1))


def load_circuit(path):
    circ = aiger.load(path)
    outs = sorted(circ.outputs, key=output_key)
    return circ, outs


def check(op, aig_path, verbose=True):
    circ, outs = load_circuit(aig_path)
    n = len(outs)

    if verbose:
        print("circuit   : %s" % os.path.basename(aig_path))
        print("inputs    : %d" % len(circ.inputs))
        print("outputs   : %d" % n)

    # -- read back the true input -> BDD-variable mapping ------------------
    probe = autoref.BDD()
    probe.configure(reordering=True)
    _, _, i2v = aiger_bdd.to_bdd(circ, output=outs[0], manager=probe)
    del probe

    # -- declare variables in interleaved order ----------------------------
    # The circuit may not reference every operand bit (a shifter only uses
    # b[0:5]). Declare the full width anyway so the interleaving is uniform
    # and the reference model has a variable for every bit it needs.
    width = n
    mgr = autoref.BDD()

    def var_name(operand_ch, idx):
        for cand in ("%s[%d]" % (operand_ch, idx), "%s%d" % (operand_ch, idx)):
            if cand in i2v:
                return i2v[cand]
        return "__unused_%s%d" % (operand_ch, idx)   # not driven by the circuit

    ordered = []
    for i in range(width):
        ordered.append(var_name("a", i))
        ordered.append(var_name("b", i))
    for v in ordered:
        mgr.declare(v)

    if verbose:
        used = sorted(i2v, key=interleaved_key)
        print("var order : %s ..." % ", ".join(used[:6]))
        if len(i2v) < 2 * width:
            print("note      : circuit references %d of %d operand bits"
                  % (len(i2v), 2 * width))

    # -- build the circuit BDDs --------------------------------------------
    t0 = time.time()
    circuit_roots = [aiger_bdd.to_bdd(circ, output=o, manager=mgr)[0]
                     for o in outs]
    t_circuit = time.time() - t0

    # -- build the reference BDDs in the SAME manager ----------------------
    a = [mgr.var(var_name("a", i)) for i in range(width)]
    b = [mgr.var(var_name("b", i)) for i in range(width)]

    t0 = time.time()
    reference_roots = rmg.reference(op, a, b, mgr)
    t_reference = time.time() - t0

    if len(reference_roots) != n:
        print("ERROR: reference produced %d roots, circuit has %d outputs"
              % (len(reference_roots), n))
        return False

    # -- compare -----------------------------------------------------------
    mismatches = []
    for i, (cu, ru) in enumerate(zip(circuit_roots, reference_roots)):
        if cu != ru:
            mismatches.append(i)

    if verbose:
        sizes = [len(u) for u in circuit_roots]
        print("build     : circuit %.2fs, reference %.2fs" % (t_circuit, t_reference))
        print("per-bit   : %s ... %d" % (sizes[:5], sizes[-1]))
        print("sum       : %d" % sum(sizes))
        print()

    if not mismatches:
        print("EQUIVALENT  %s : all %d output bits match the reference model"
              % (op.upper(), n))
        ok = True
    else:
        print("NOT EQUIVALENT  %s : %d of %d output bits differ: %s"
              % (op.upper(), len(mismatches), n, mismatches[:8]))
        i = mismatches[0]
        diff = mgr.apply("xor", circuit_roots[i], reference_roots[i])
        try:
            witness = mgr.pick(diff)
            v2i = {v: k for k, v in i2v.items()}
            named = {}
            for var, val in witness.items():
                named[v2i.get(var, var)] = int(val)
            a_val = sum((named.get("a[%d]" % k, 0) << k) for k in range(width))
            b_val = sum((named.get("b[%d]" % k, 0) << k) for k in range(width))
            print("counterexample on bit %d:  a = 0x%08X   b = 0x%08X"
                  % (i, a_val, b_val))
            print("(unlisted input bits are don't-care)")
        except Exception as exc:
            print("could not extract a counterexample: %s" % exc)
        ok = False

    del circuit_roots
    del reference_roots
    return ok


def main():
    args = [x for x in sys.argv[1:] if not x.startswith("-")]
    verbose = "--quiet" not in sys.argv

    if not args:
        print("usage: python3 equiv.py <op> [--quiet]")
        print("ops:   %s" % ", ".join(rmg.OPS))
        return 2

    op = args[0].lower()
    if op not in rmg.OPS:
        print("unknown op %r; known: %s" % (op, ", ".join(rmg.OPS)))
        return 2

    here = os.path.dirname(os.path.abspath(__file__))
    aig_path = os.path.join(here, "aig", op + ".aag")
    if not os.path.isfile(aig_path):
        print("missing %s -- run extract.sh %s first" % (aig_path, op))
        return 2

    return 0 if check(op, aig_path, verbose) else 1


if __name__ == "__main__":
    sys.exit(main())

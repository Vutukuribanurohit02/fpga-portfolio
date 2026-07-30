"""
test_rmg.py -- exhaustive validation of the reference model generator.

Builds each operation's reference BDDs at a small datapath width, then
evaluates them over *every* input assignment and compares against Python
integer arithmetic. At width 6 that is 4096 assignments per operation.

This validates the RMG itself. Without it, an equivalence "PASS" would only
prove the circuit matches a possibly-wrong reference.

Run:  python3 test_rmg.py [width]
"""

import sys
import itertools
from dd import autoref
import rmg

WIDTH = int(sys.argv[1]) if len(sys.argv) > 1 else 6


def build_vars(n):
    """Declare interleaved a/b variables and return (mgr, a_list, b_list)."""
    mgr = autoref.BDD()
    names = []
    for i in range(n):
        names.append("a%d" % i)
        names.append("b%d" % i)
    for nm in names:
        mgr.declare(nm)
    a = [mgr.var("a%d" % i) for i in range(n)]
    b = [mgr.var("b%d" % i) for i in range(n)]
    return mgr, a, b


def evaluate(mgr, roots, a_val, b_val, n):
    """Evaluate the root list under a concrete assignment; return an integer."""
    assign = {}
    for i in range(n):
        assign["a%d" % i] = bool((a_val >> i) & 1)
        assign["b%d" % i] = bool((b_val >> i) & 1)
    out = 0
    for i, u in enumerate(roots):
        r = mgr.let(assign, u)
        if r == mgr.true:
            out |= (1 << i)
        elif r != mgr.false:
            raise AssertionError("bit %d did not evaluate to a constant" % i)
    return out


def to_signed(x, n):
    return x - (1 << n) if x & (1 << (n - 1)) else x


def expected(op, a_val, b_val, n):
    """Golden semantics, computed with Python integers."""
    mask = (1 << n) - 1
    nbits = 5 if n >= 32 else max(1, (n - 1).bit_length())
    shamt = b_val & ((1 << nbits) - 1)

    if op == "and":
        return a_val & b_val
    if op == "or":
        return a_val | b_val
    if op == "xor":
        return a_val ^ b_val
    if op == "add":
        return (a_val + b_val) & mask
    if op == "sub":
        return (a_val - b_val) & mask
    if op == "sltu":
        return 1 if a_val < b_val else 0
    if op == "slt":
        return 1 if to_signed(a_val, n) < to_signed(b_val, n) else 0
    if op == "sll":
        return (a_val << shamt) & mask
    if op == "srl":
        return (a_val >> shamt) & mask
    if op == "sra":
        return (to_signed(a_val, n) >> shamt) & mask
    raise ValueError(op)


def main():
    n = WIDTH
    print("Exhaustive RMG validation at width %d (%d assignments per op)\n"
          % (n, (1 << n) ** 2))

    all_ok = True
    for op in rmg.OPS:
        mgr, a, b = build_vars(n)
        roots = rmg.reference(op, a, b, mgr)

        if len(roots) != n:
            print("  %-5s FAIL  expected %d roots, got %d" % (op, n, len(roots)))
            all_ok = False
            continue

        bad = 0
        first_bad = None
        for a_val, b_val in itertools.product(range(1 << n), repeat=2):
            got = evaluate(mgr, roots, a_val, b_val, n)
            want = expected(op, a_val, b_val, n)
            if got != want:
                bad += 1
                if first_bad is None:
                    first_bad = (a_val, b_val, got, want)

        nodes = len(mgr)
        if bad == 0:
            print("  %-5s PASS   all %d assignments   (manager: %d nodes)"
                  % (op, (1 << n) ** 2, nodes))
        else:
            a_val, b_val, got, want = first_bad
            print("  %-5s FAIL   %d mismatches; first: a=%d b=%d got=%d want=%d"
                  % (op, bad, a_val, b_val, got, want))
            all_ok = False

    print()
    print("RESULT:", "ALL OPERATIONS VALIDATED" if all_ok else "FAILURES PRESENT")
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())

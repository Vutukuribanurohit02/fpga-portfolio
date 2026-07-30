"""
gen_test_aig.py -- build stand-in AIGER files for testing equiv.py without Yosys.

Constructs each ALU operation as a *ripple-carry / naive* implementation using
py-aiger, mirroring what Yosys emits from behavioural RTL. The reference model
in rmg.py uses parallel-prefix carries and a barrel shifter, so agreement is a
real check rather than a tautology.

Also emits a deliberately broken adder (bad_add.aag) with an inverted carry
into bit 17, to confirm the checker detects faults and reports a counterexample.

    python3 gen_test_aig.py [width]
"""

import os
import sys
import aiger

WIDTH = int(sys.argv[1]) if len(sys.argv) > 1 else 32
OUTDIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "aig")


def inputs(n):
    a = [aiger.atom("a[%d]" % i) for i in range(n)]
    b = [aiger.atom("b[%d]" % i) for i in range(n)]
    return a, b


def ripple_add(a, b, cin, n):
    """Naive ripple-carry: the structure Yosys infers from `a + b`."""
    s, c = [], cin
    for i in range(n):
        s.append(a[i] ^ b[i] ^ c)
        c = (a[i] & b[i]) | (c & (a[i] ^ b[i]))
    return s, c


def ripple_sub(a, b, n):
    return ripple_add(a, [~x for x in b], aiger.atom(True), n)


def naive_shift(src, shamt_bits, fill, left, n):
    """Cascaded power-of-two stages."""
    cur = list(src)
    for stage, sel in enumerate(shamt_bits):
        amt = 1 << stage
        nxt = []
        for i in range(n):
            j = i - amt if left else i + amt
            moved = cur[j] if 0 <= j < n else fill
            nxt.append((sel & moved) | (~sel & cur[i]))
        cur = nxt
    return cur


def build(op, n, broken=False):
    a, b = inputs(n)
    zero = aiger.atom(False)
    nbits = 5 if n >= 32 else max(1, (n - 1).bit_length())
    shamt = b[:nbits]

    if op == "and":
        r = [a[i] & b[i] for i in range(n)]
    elif op == "or":
        r = [a[i] | b[i] for i in range(n)]
    elif op == "xor":
        r = [a[i] ^ b[i] for i in range(n)]
    elif op == "add":
        if broken:
            # inject a fault: invert the carry entering bit 17
            s, c = [], zero
            for i in range(n):
                cc = ~c if i == 17 else c
                s.append(a[i] ^ b[i] ^ cc)
                c = (a[i] & b[i]) | (c & (a[i] ^ b[i]))
            r = s
        else:
            r, _ = ripple_add(a, b, zero, n)
    elif op == "sub":
        r, _ = ripple_sub(a, b, n)
    elif op == "sltu":
        _, cout = ripple_sub(a, b, n)
        r = [~cout] + [zero] * (n - 1)
    elif op == "slt":
        d, _ = ripple_sub(a, b, n)
        diff_sign = a[n - 1] ^ b[n - 1]
        lt = (diff_sign & a[n - 1]) | (~diff_sign & d[n - 1])
        r = [lt] + [zero] * (n - 1)
    elif op == "sll":
        r = naive_shift(a, shamt, zero, True, n)
    elif op == "srl":
        r = naive_shift(a, shamt, zero, False, n)
    elif op == "sra":
        r = naive_shift(a, shamt, a[n - 1], False, n)
    else:
        raise ValueError(op)

    circ = None
    for i, expr in enumerate(r):
        piece = expr.aig
        old = list(piece.outputs)[0]
        piece = piece["o", {old: "result[%d]" % i}]
        circ = piece if circ is None else (circ | piece)
    return circ


def main():
    os.makedirs(OUTDIR, exist_ok=True)
    jobs = [(op, False) for op in
            ["add", "sub", "and", "or", "xor", "slt", "sltu", "sll", "srl", "sra"]]
    jobs.append(("add", True))

    for op, broken in jobs:
        circ = build(op, WIDTH, broken)
        name = ("bad_" + op) if broken else op
        path = os.path.join(OUTDIR, name + ".aag")
        with open(path, "w") as fh:
            fh.write(circ.aig.__str__() if hasattr(circ, "aig") else str(circ))
        with open(path) as fh:
            header = fh.readline().strip()
        print("%-10s %s" % (name, header))


if __name__ == "__main__":
    main()

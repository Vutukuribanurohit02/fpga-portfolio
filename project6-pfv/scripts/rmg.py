"""
rmg.py -- Reference Model Generator.

Builds a golden BDD for each ALU operation directly from the RV32I instruction
semantics, independent of the synthesised circuit. This is the component the
paper calls RMG.

Design note -- why the adder is built as a parallel-prefix network
------------------------------------------------------------------
An ROBDD is canonical: for a fixed variable order, a Boolean function has
exactly one ROBDD. Two *structurally different* circuits computing the same
function therefore produce the *identical* BDD.

The reference adder here is a Kogge-Stone style parallel-prefix carry network.
The circuit under test synthesises to a ripple-carry chain. They share no
structure whatsoever, yet must yield identical BDDs if both compute 32-bit
addition. That makes the equivalence check a genuine test rather than a
tautology, and it demonstrates canonicity doing real work.

API
---
    reference(op, a, b, mgr) -> list[BDD]     # 32 roots, LSB first

`a` and `b` are lists of BDD nodes (LSB first). The caller is responsible for
mapping circuit input names onto BDD variables, so this module has no
dependency on AIGER naming.
"""

OPS = ["add", "sub", "and", "or", "xor", "slt", "sltu", "sll", "srl", "sra"]

# ALU opcode encoding, matching alu.sv
OPCODES = {
    "add":  "0000",
    "sub":  "0001",
    "and":  "0010",
    "or":   "0011",
    "xor":  "0100",
    "slt":  "0101",
    "sltu": "0110",
    "sll":  "0111",
    "srl":  "1000",
    "sra":  "1001",
}


# ---------------------------------------------------------------- helpers

def _ite(g, u, v):
    """if g then u else v."""
    return (g & u) | (~g & v)


def _xor(mgr, u, v):
    """dd 0.5.7's autoref Function has no ^ operator; use the manager."""
    return mgr.apply("xor", u, v)


def _prefix_carries(a, b, cin, mgr):
    """
    Kogge-Stone parallel-prefix carry computation.

    Returns (carries, cout) where carries[i] is the carry *into* bit i.

    Deliberately not a ripple-carry recurrence: carries are computed by
    log-depth prefix combination of (generate, propagate) pairs, so this
    shares no structure with the circuit under test.
    """
    n = len(a)

    # bit-level generate / propagate
    g = [a[i] & b[i] for i in range(n)]
    p = [_xor(mgr, a[i], b[i]) for i in range(n)]

    # prefix combination:  (G,P) o (G',P') = (G | (P & G'),  P & P')
    # G[i], P[i] accumulate the span ending at bit i.
    G, P = list(g), list(p)
    dist = 1
    while dist < n:
        newG, newP = list(G), list(P)
        for i in range(dist, n):
            j = i - dist
            newG[i] = G[i] | (P[i] & G[j])
            newP[i] = P[i] & P[j]
        G, P = newG, newP
        dist *= 2

    # carry into bit i = G[i-1] | (P[i-1] & cin)
    carries = [cin]
    for i in range(1, n):
        carries.append(G[i - 1] | (P[i - 1] & cin))

    cout = G[n - 1] | (P[n - 1] & cin)
    return carries, cout


def _add(a, b, cin, mgr):
    """Full adder network. Returns (sum_bits, cout)."""
    n = len(a)
    carries, cout = _prefix_carries(a, b, cin, mgr)
    s = [_xor(mgr, _xor(mgr, a[i], b[i]), carries[i]) for i in range(n)]
    return s, cout


def _sub(a, b, mgr):
    """Two's complement subtraction: a - b = a + ~b + 1. Returns (diff, cout)."""
    b_inv = [~x for x in b]
    return _add(a, b_inv, mgr.true, mgr)


def _barrel(src, shamt, fill, left, mgr):
    """
    Generic barrel shifter, 5 stages of power-of-two shifts.

    src   : list of BDD nodes, LSB first
    shamt : list of 5 BDD nodes (the shift-amount bits, LSB first)
    fill  : BDD node shifted in (constant 0, or the sign bit for SRA)
    left  : True for left shift, False for right
    """
    n = len(src)
    cur = list(src)
    for stage in range(len(shamt)):
        amount = 1 << stage
        sel = shamt[stage]
        nxt = []
        for i in range(n):
            if left:
                src_idx = i - amount
            else:
                src_idx = i + amount
            shifted = cur[src_idx] if 0 <= src_idx < n else fill
            nxt.append(_ite(sel, shifted, cur[i]))
        cur = nxt
    return cur


# ---------------------------------------------------------------- the RMG

def reference(op, a, b, mgr):
    """
    Build the golden BDD roots for `op`.

    a, b : lists of BDD nodes, LSB first, same length (the datapath width)
    mgr  : the dd BDD manager (must already have all variables declared)

    Returns a list of BDD nodes, LSB first, one per result bit.
    """
    if len(a) != len(b):
        raise ValueError("operand widths differ: %d vs %d" % (len(a), len(b)))
    n = len(a)
    op = op.lower()

    if op == "and":
        return [a[i] & b[i] for i in range(n)]

    if op == "or":
        return [a[i] | b[i] for i in range(n)]

    if op == "xor":
        return [_xor(mgr, a[i], b[i]) for i in range(n)]

    if op == "add":
        s, _ = _add(a, b, mgr.false, mgr)
        return s

    if op == "sub":
        d, _ = _sub(a, b, mgr)
        return d

    if op == "sltu":
        # unsigned a < b  <=>  no carry out of (a + ~b + 1), i.e. a borrow occurred
        _, cout = _sub(a, b, mgr)
        lt = ~cout
        return [lt] + [mgr.false] * (n - 1)

    if op == "slt":
        # signed: if the sign bits differ, a is smaller exactly when a is negative;
        # otherwise the sign of (a - b) decides.
        d, _ = _sub(a, b, mgr)
        sign_differ = _xor(mgr, a[n - 1], b[n - 1])
        lt = _ite(sign_differ, a[n - 1], d[n - 1])
        return [lt] + [mgr.false] * (n - 1)

    if op in ("sll", "srl", "sra"):
        # RV32I uses only the low 5 bits of the shift operand
        nbits = 5 if n >= 32 else max(1, (n - 1).bit_length())
        shamt = b[:nbits]
        if op == "sll":
            return _barrel(a, shamt, mgr.false, True, mgr)
        if op == "srl":
            return _barrel(a, shamt, mgr.false, False, mgr)
        return _barrel(a, shamt, a[n - 1], False, mgr)   # sra: sign fill

    raise ValueError("unknown operation: %r (known: %s)" % (op, ", ".join(OPS)))

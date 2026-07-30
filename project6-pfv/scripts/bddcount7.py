import sys, os, re, time, resource, aiger, aiger_bdd
from dd import autoref

resource.setrlimit(resource.RLIMIT_AS, (5 * 1024**3, 5 * 1024**3))

name = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
circ = aiger.load(os.path.join(here, "aig", name + ".aag"))
outs = sorted(circ.outputs)

# Probe: read the real input -> BDD-variable mapping.
probe = autoref.BDD()
_, _, i2v = aiger_bdd.to_bdd(circ, output=outs[0], manager=probe)
del probe

def key(inp):
    m = re.match(r'([ab])\[(\d+)\]', inp) or re.match(r'([ab])(\d+)', inp)
    return (int(m.group(2)), 0 if m.group(1) == 'a' else 1)

manager = autoref.BDD()
for inp in sorted(i2v, key=key):
    manager.declare(i2v[inp])

lv = [manager.var_at_level(i) for i in range(6)]
inv = {v: k for k, v in i2v.items()}
print("circuit         :", name)
print("levels, first 6 :", [inv[v] for v in lv], flush=True)

t0 = time.time()
roots = [aiger_bdd.to_bdd(circ, output=o, manager=manager)[0] for o in outs]
print("manager nodes   : %d   (%.1fs)" % (len(manager), time.time()-t0))
print("sum per-output  :", sum(len(u) for u in roots))
print("max per-output  :", max(len(u) for u in roots))
del roots

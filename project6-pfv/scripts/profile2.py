import os, sys
if os.environ.get("PYTHONHASHSEED") != "0":
    os.environ["PYTHONHASHSEED"] = "0"
    os.execv(sys.executable, [sys.executable] + sys.argv)

import re, resource, aiger, aiger_bdd
from dd import autoref

resource.setrlimit(resource.RLIMIT_AS, (5 * 1024**3, 5 * 1024**3))

name = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
circ = aiger.load(os.path.join(here, "aig", name + ".aag"))
outs = sorted(circ.outputs, key=lambda s: int(re.search(r'(\d+)', s).group(1)))

probe = autoref.BDD()
probe.configure(reordering=True)
_, _, i2v = aiger_bdd.to_bdd(circ, output=outs[0], manager=probe)
del probe

def key(inp):
    m = re.match(r'([ab])\[(\d+)\]', inp) or re.match(r'([ab])(\d+)', inp)
    return (int(m.group(2)), 0 if m.group(1) == 'a' else 1)

manager = autoref.BDD()
for inp in sorted(i2v, key=key):
    manager.declare(i2v[inp])

inv = {v: k for k, v in i2v.items()}
print("levels 0-5 :", [inv[manager.var_at_level(i)] for i in range(6)])

roots = [aiger_bdd.to_bdd(circ, output=o, manager=manager)[0] for o in outs]
sizes = [len(u) for u in roots]
print(name, "per-bit BDD sizes:")
for i, s in enumerate(sizes):
    print("  bit %2d : %4d" % (i, s))
print("sum :", sum(sizes))
print("diffs:", [sizes[i+1]-sizes[i] for i in range(len(sizes)-1)])
del roots

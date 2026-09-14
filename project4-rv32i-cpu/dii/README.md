# DII — differential instruction injection

A differential tester for the RV32I core. Random instruction sequences are run
against both the Verilated RTL and a Python reference model; the two RVFI traces
are compared field by field. On a mismatch the failing sequence is shrunk to a
minimal one that still fails.

## Files

| File | Role |
|---|---|
| `build.sh` | Verilator build. Compiles the core with `RISCV_FORMAL` defined so the RVFI trace port is exposed, links `sim_main.cpp`, emits `obj_dir/dii_sim`. |
| `sim_main.cpp` | C++ harness. Injects instructions into the fetch path by retirement index and dumps the RVFI record per retired instruction. |
| `model.py` | Reference model, written from the RISC-V spec rather than derived from the design. |
| `fuzz.py` | Sequence generator, RVFI differ, and delta-debugging shrinker. |
| `smoke.hex` | Small sequence for checking the harness itself builds and runs. |

## Build

Requires Verilator. Output is `obj_dir/dii_sim`.

## Run

## Notes on the comparison

Not every RVFI field carries meaning on every instruction. `mem_addr` is driven
from the ALU result on all instructions and `mem_rdata` reflects whatever the bus
returned, so both are noise unless a read or write mask is set. `meaningful()`
in `fuzz.py` drops those fields when no mask is present; comparing them
unconditionally produces false mismatches.

## Why the shrinker matters

A 500-instruction mismatch says almost nothing about the cause. The shrinker
reduces it to the smallest sequence that still reproduces the failure, which is
usually short enough to read directly.

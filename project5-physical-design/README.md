# Project 05 — RTL-to-GDSII: RV32I ALU on SkyWater 130nm

A formally verified 32-bit RISC-V ALU taken through a complete open-source
physical design flow — synthesised, placed, routed, and signed off across nine
process-voltage-temperature corners on the sky130A open PDK.

Every number below comes from `metrics/metrics_33ns.json`. Nothing is estimated.

Full write-up with die renders: **[vutukuribanurohit02.github.io/fpga-portfolio/project5-physical-design](https://vutukuribanurohit02.github.io/fpga-portfolio/project5-physical-design/)**

---

## Result

| | |
|---|---|
| Die area | 21,303 µm² (140.7 × 151.4 µm) |
| Standard cells | 1,293 (plus 1,782 fill, 220 tap) |
| Core utilisation | 64.6% |
| Routed wirelength | 38.19 mm |
| Worst-case frequency | 31.5 MHz (`max_ss_100C_1v60`) |
| Best-case frequency | 56.3 MHz (`max_ff_n40C_1v95`) |
| DRC (Magic / KLayout) | 0 / 0 |
| LVS errors | 0 |
| Antenna violations | 0 |
| Inferred latches | 0 |
| Power-grid violations | 0 |
| Total power | 213 µW |

## Nine-corner static timing

Constraint: `CLOCK_PERIOD = 33 ns`. TNS is 0.000 at every corner.

| Corner | Process | V / T | Worst slack |
|---|---|---|---|
| `min_ff_n40C_1v95` | fast | 1.95 V · −40 °C | +15.422 ns |
| `nom_ff_n40C_1v95` | fast | 1.95 V · −40 °C | +15.330 ns |
| `max_ff_n40C_1v95` | fast | 1.95 V · −40 °C | +15.237 ns |
| `min_tt_025C_1v80` | typical | 1.80 V · 25 °C | +11.883 ns |
| `nom_tt_025C_1v80` | typical | 1.80 V · 25 °C | +11.752 ns |
| `max_tt_025C_1v80` | typical | 1.80 V · 25 °C | +11.623 ns |
| `min_ss_100C_1v60` | slow | 1.60 V · 100 °C | +1.756 ns |
| `nom_ss_100C_1v60` | slow | 1.60 V · 100 °C | +1.511 ns |
| `max_ss_100C_1v60` | slow | 1.60 V · 100 °C | +1.267 ns |

The binding corner is `max_ss_100C_1v60` — slow silicon, hottest junction,
lowest rail. Sweeping the clock constraint across 32, 33, 34, 40, 50 and 60 ns
produced slack that tracked the period one-for-one, which proves the
combinational critical path is a fixed **31.733 ns** independent of the target.
That is where 31.5 MHz comes from, and it is the number a datasheet would print.

Same mask, same transistors, 1.8× spread from physics alone.

## What the flow revealed

**Zero inferred latches, confirmed rather than assumed.** An incomplete
`always_comb` branch quietly synthesises state where none should exist. The
lint stage reports zero; that was checked, not taken on faith.

**The 208 timing-repair buffers are not a setup-timing artefact.** Buffer
count, cell count and die area were bit-for-bit identical at every clock period
from 32 ns to 60 ns. Sweeping the constraint and watching nothing move rules
out setup as the cause — those buffers exist to satisfy max-slew and max-cap
electrical rules.

**The critical path is a named structure, not a guess.** Gate-level tracing
with OpenSTA located a five-gate OR/NOR chain
(`or4b → or4 → or3 → or4 → or4 → nor4`) implementing the 32-bit zero flag as a
flat linear reduction instead of a balanced tree.

**Clock tree synthesis is correctly a no-op.** The ALU is purely
combinational, so there is no clock and nothing to build. A silently failed CTS
looks identical to a correctly skipped one unless you check, so this was
verified too.

## Open items

**Max-slew violations in six of nine corners.** 19 at `min_tt`, 50 at
`nom_tt`, 83 at `max_tt`, 354 at `min_ss`, 429 at `nom_ss`, 495 at `max_ss`.
Max-cap violates in one corner (`max_ss`, count 1). These are electrical rule
margins rather than sign-off blockers — timing closes cleanly at every corner
and physical verification is clean — but the design is not electrically clean
and this README does not claim it is.

**The ripple-carry adder sets the floor.** Its O(n) carry chain is what makes
the critical path 31.7 ns. Carry-lookahead is the next iteration, and the
before/after frequency delta will be measured with this same flow rather than
argued.

## Toolchain

LibreLane 3.x · OpenROAD · Yosys + Slang · Magic · Netgen · KLayout · OpenSTA,
pinned through Nix against the FOSSi binary cache. No proprietary tools.

## Reproduce

The metrics, the render scripts and the sign-off GDS are in this directory.
The LibreLane flow configuration lives outside the repo and is not committed. Every image on the project page regenerates from the TCL scripts —
nothing here is a screenshot that cannot be rebuilt.

| File | |
|---|---|
| `metrics/metrics_33ns.json` | every number quoted above |
| `config/*.tcl` | render scripts for the die images |
| `config/sweep.sh` | the clock-constraint sweep |
| `alu.gds` | signed-off layout |

---

The RTL hardened here is the same ALU formally proven in
[Project 03](../project3-rv32i-alu) and proven equivalent by ROBDD in
[Project 06](../project6-pfv). It was subsequently wrapped and submitted to
Tiny Tapeout as [Project 07](https://github.com/Vutukuribanurohit02/ttsky26c-rv32i-alu).

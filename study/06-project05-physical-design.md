# Project 05 — Physical Design: RTL to GDSII

**One line:** the formally verified ALU hardened from RTL to routed silicon on the SkyWater open PDK, signed off across nine PVT corners.

---

## What it is

The full open-source RTL-to-GDSII flow — LibreLane and OpenROAD on sky130 — applied to the ALU from Project 3. Synthesized, placed, routed, RC-extracted, and timing-signed-off across nine process-voltage-temperature corners.

**Not simulated. Not estimated. Laid out.**

---

## Why this rung exists

Everything before Project 5 is behaviour. Physical design is where a design acquires area, delay, power and manufacturability — where "correct" stops being a binary and becomes a question of *under which conditions*.

A portfolio that stops at RTL demonstrates half the discipline. Most student portfolios stop at RTL.

---

## The flow, step by step

1. **Synthesis** — RTL mapped to sky130 standard cells; output is a gate-level netlist
2. **Floorplan** — die area, core area, pin placement
3. **Placement** — every cell gets coordinates
4. **Routing** — metal layers connect everything
5. **RC extraction** — real resistance and capacitance pulled from the routed geometry
6. **Sign-off STA** — timing re-checked against extracted parasitics, across nine corners
7. **Physical verification** — DRC, LVS, antenna

Note the ordering of 5 and 6. Timing checked before extraction uses estimated wire delays. Timing checked after extraction uses the delays the actual layout will have. Only the second is sign-off.

---

## Results

| Metric | Value |
|---|---|
| Worst-case frequency | **31.5 MHz** |
| Best-case frequency | **56.3 MHz** |
| PVT spread | **1.8×** on identical silicon |
| DRC violations | 0 |
| LVS violations | 0 |
| Antenna violations | 0 |
| Inferred latches | 0 (confirmed by lint) |
| Corners characterised | 9 |

### The number that teaches the most

**1.8× spread across PVT corners on the same physical design.**

This is the concrete answer to a question textbooks state and don't demonstrate: why do designers quote corners rather than a frequency? Because the same die runs at 31.5 MHz in a slow-process, low-voltage, high-temperature corner and 56.3 MHz in a fast one. Quoting only the best number is marketing; quoting only the worst wastes performance; quoting the corner set is engineering.

The spread was characterised by a linear constraint sweep rather than assumed.

---

## The named next iteration

The gate-level critical path was traced with **OpenSTA** to a specific structure, and the fix named: **a carry-lookahead adder** in place of the ripple-carry chain.

This matters as a result in itself. "It met timing" says you ran the tool. "The critical path is the carry chain through bit 31 and the fix is carry-lookahead" says you read the timing report and understood what it was telling you. Interviewers can tell the difference in about one follow-up question.

---

## What this project shares with Project 7, and how they differ

Both harden the same RTL. That is deliberate — it makes a controlled comparison possible.

| | Project 5 | Project 7 |
|---|---|---|
| Floorplan | Free | Fixed 1×1 tile |
| Design type | Purely combinational | Sequential (68 flip-flops) |
| Clock tree | None | 117 buffers, 0.255 ns skew |
| Reg-to-reg slack | Infinity (no reg-to-reg paths) | +10.49 ns |
| Sign-off | 9 corners characterised | Single corner, setup +0.425 ns |

Reg-to-reg slack going from infinity to a finite number, and skew from zero to 0.255 ns, is the tool showing you what a clock tree costs — measured on the same RTL rather than asserted from a textbook.

**Honest caveat:** part of the difference between the two is constraint-driven rather than design-driven. Re-running Project 5 at 25 ns on a fixed die would isolate the clock-tree effect from the clock-constraint effect. Flagging that is what makes the rest of the comparison credible.

---

## Questions you should be able to answer

1. What are the nine corners, and which one usually sets the worst-case frequency?
2. Why must STA be re-run after RC extraction?
3. What is the difference between a DRC violation and an LVS violation, in terms of what goes wrong?
4. What is an antenna violation actually about, physically?
5. Why does a purely combinational design have no hold analysis worth discussing?
6. How would carry-lookahead change the critical path, and what does it cost in area?
7. What does a 1.8× PVT spread imply for how you'd specify this part in a datasheet?

## Where it leads

Project 7 hardens the same block again — this time on a fixed die you cannot probe, which changes the interface problem entirely.

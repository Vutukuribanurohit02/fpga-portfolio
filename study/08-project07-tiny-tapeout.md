# Project 07 — Tiny Tapeout: RV32I ALU on a shared wafer

**One line:** the same formally verified ALU wrapped for the TTSKY26c shuttle — 101 signals through 24 pins, hardened with a real clock tree, and closed with positive slack on every path.

---

## What it is

A submission to the **Tiny Tapeout TTSKY26c** shuttle on SkyWater 130 nm. A 1×1 tile carrying the ALU from Project 3, wrapped in a byte-addressed register interface, hardened in LibreLane 3.x, and signed off clean.

**The interesting part is not the ALU.** It is getting a 101-signal datapath through a 24-pin fixed interface, and closing timing on a die you don't get to size.

---

## The constraint

Tiny Tapeout gives every project the same pinout: `ui_in[7:0]` in, `uo_out[7:0]` out, `uio[7:0]` bidirectional. Twenty-four pins.

The ALU needs **68 input bits** (`a[31:0]`, `b[31:0]`, `alu_op[3:0]`) and produces **33 output bits** (`result[31:0]`, `zero`). That is four times oversubscribed on input alone.

The RTL itself is unchanged — byte-for-byte the module formally verified in Project 3 and hardened standalone in Project 5. Everything around it is new.

---

## The design decision that matters

### Why not a serialisation FSM

The obvious approach is shifting operands in behind a handshake. It was rejected, and the reasoning is the strongest thing to be able to explain about this project:

An FSM carries **sequencing state**, and sequencing state can **desynchronise**. If the host and the chip disagree about which byte comes next, there is no way to detect it from outside and no recovery short of a full reset. On a die with no probe access, that is a bad trade.

### What was built instead

A **byte-addressed register file**. The host writes any byte in any order, rewrites any single byte, and reads the result back a byte at a time.

There is no protocol state to lose, and **no illegal states** — any sequence of writes leaves the chip in a valid configuration, because no sequence is being tracked.

Cost: **68 flip-flops**, and with them a real clock tree and hold analysis. This is what turns a combinational block into a sequential design.

### Interface

**Writes:** `ui_in[7:0]` is data, `uio_in[3:0]` is address, `uio_in[4]` is write enable, captured on the rising clock edge.

| Address | Target |
|---|---|
| `0`–`3` | `a[31:0]`, byte 0 = LSB |
| `4`–`7` | `b[31:0]`, byte 0 = LSB |
| `8` | `alu_op[3:0]` (low nibble) |
| `9` | **accumulate** — loads `a <= result` |

**Reads:** purely combinational, no clock needed. `uio_in[6:5]` selects which result byte appears on `uo_out[7:0]`. The zero flag sits permanently on `uio_out[7]`, with `uio_oe = 8'b1000_0000`.

### The accumulate address

Address 9 is not a register. Writing to it feeds the ALU result back into `a`, turning a stateless calculator into an accumulator: load `a` and the opcode once, then stream `b` values and pulse address 9 after each. A running total costs one clock per operation instead of a nine-byte reload.

In RTL it is one case arm. **Physically it is the design's only register-to-register path** — `a → ALU → a` through the full 32-bit datapath — and it is what gives static timing analysis something real to close. That arc has **+10.49 ns** of slack, comfortably the least critical path in the design.

---

## Sign-off results

| Metric | Value | Metric | Value |
|---|---|---|---|
| Setup worst slack | **+0.425 ns** | Standard cells | 1,602 |
| Reg-to-reg setup slack | +10.49 ns | Core utilisation | 85.5% |
| Hold worst slack | +0.117 ns | Routed wirelength | 55.4 mm |
| Clock skew | 0.255 ns | Flip-flops | 68 |
| DRC / LVS / antenna | 0 / 0 / 0 | Clock buffers | 117 |

Every figure comes from `tt_submission/stats/metrics.csv` in the `gds` workflow artifact.

---

## The violation the green checkmark hid

The first hardened build passed DRC, LVS, antenna and every gate-level test. The workflow reported success.

**It also carried a −2.19 ns setup violation**, because the shuttle's CI does not fail on timing.

It was found by parsing `metrics.csv` out of the build artifact rather than reading the summary page. The failing path was not the new accumulate arc — that had positive slack throughout — but the older register-to-output path, `a_reg → ALU → result mux → pad`, measuring 22.2 ns against the template's default 20 ns constraint.

**The fix was one line:** `CLOCK_PERIOD` from 20 ns to 25 ns. For a host-paced register interface the operating frequency is irrelevant — nothing streams — so the only thing given up is a datasheet number. Utilisation dropped from 85.2% to 80.4% in the process, because the relaxed constraint let synthesis pick smaller cells.

The final +0.425 ns is thin, about 1.7% margin, putting the real critical path at 24.6 ns.

**This is the most valuable story in the project.** Anyone can produce a green build. Knowing what your CI actually checks, and going to read the numbers behind it, is the difference.

---

## Verification

`test/test.py`, cocotb, **ten tests**, all passing at RTL *and* against the post-route gate-level netlist:

| Test | Covers |
|---|---|
| `test_pin_directions` | `uio_oe` drives only bit 7 |
| `test_reset_state` | Registers clear on `rst_n` |
| `test_directed` | 14 hand-picked vectors — zero-flag wrap, borrow, sign-extending SRA, shift truncation to `b[4:0]`, the SLT/SLTU pair |
| `test_random` | 120 constrained-random vectors across all ten opcodes, seeded, checked against a Python golden model |
| `test_partial_write` | Writing one operand byte leaves the other eight untouched |
| `test_no_write_when_we_low` | Data ignored when write enable is low |
| `test_reset_clears` | Reset mid-sequence returns to a known state |
| `test_accumulate` | Address 9 loads `a <= result` |
| `test_accumulate_running_total` | Repeated accumulate produces a correct running sum |
| `test_accumulate_needs_write_enable` | Address 9 is gated like any other write |

Note what the last four tests are for: they test the **interface for misuse**, not the arithmetic. That is the part a verification engineer notices.

**Simulating the post-route netlist is the check that matters** — it is the only one confirming that what got routed still does what the RTL did.

---

## Honest scope

A 1×1 tile on a shared educational shuttle, not production silicon. An ALU behind a byte-wide register interface is **slower than the CPU driving it** — thirteen bus transactions per operation. It is not an accelerator and should never be presented as one.

What it is: the same RTL taken from formal proof through a fixed-die tapeout flow with a real clock tree, one timing violation caught behind a passing CI run, and a design that returns as a physical part in May 2027.

**The remaining work is the part almost nobody has:** running these same 134 vectors against the fabricated part and correlating measured behaviour with simulation. That closes RTL → formal → GDS → measured silicon.

---

## Questions you should be able to answer

1. Why is a serialisation FSM the wrong answer here, specifically?
2. What makes the byte-addressed interface free of illegal states?
3. Why does the accumulate path have the *most* slack rather than the least?
4. Why was relaxing the clock period an acceptable fix, and when would it not be?
5. Why did utilisation *drop* when the constraint was relaxed?
6. Why does hold slack matter here when it didn't in Project 5?
7. What would you check first on the physical part when it arrives in 2027?

## Where it leads

The silicon correlation in May 2027 — and, if extended, a second submission putting the Project 4 CPU core on 2×2 tiles.

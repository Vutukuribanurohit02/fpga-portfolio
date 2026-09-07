# Where this maps in the real world

Every technique in this portfolio exists because industry needs it. This document connects each one to what companies actually do with it, which roles use it daily, and how to talk about it when someone asks "so what?"

---

## The honest framing first

A portfolio project is not the same as production work, and pretending otherwise is the fastest way to lose credibility in an interview. The differences that matter:

| Portfolio | Production |
|---|---|
| One engineer, one design | Teams of tens to hundreds, shared IP |
| Educational shuttle, 1×1 tile | Full reticle, millions of dollars per mask set |
| Open PDK (sky130, 130 nm) | Foundry PDKs under NDA, 3–7 nm |
| Days of tool runtime | Weeks; regression farms running continuously |
| You choose the constraints | Constraints arrive from architecture, marketing, and physics |
| A bug costs an afternoon | A silicon bug costs a respin: months and millions |

**What transfers is not scale. It is method.** The reason a hiring manager cares that you caught a vacuous proof is that vacuous proofs happen on billion-transistor designs too, and cost far more there. The reasoning is identical; only the stakes change.

---

## 1. Bus interfaces and register maps — Project 01

### What industry does with this

Every SoC is mostly interconnect. A modern phone chip has dozens of peripherals — UART, SPI, I²C, timers, GPIO, DMA, crypto accelerators — and each one presents a register map to a bus that a CPU drives. AMBA (APB, AHB, AXI) is the dominant family; ARM licenses it and effectively everyone uses it.

The work of a junior SoC engineer is very often: take a functional block, wrap it in a bus interface, write the register map, verify the register access behaviour, and integrate it.

### Where you'd see it

- **Peripheral IP development** — Synopsys, Cadence, and internal IP teams at every large chip company
- **SoC integration** — connecting third-party IP to the internal bus fabric
- **Firmware co-design** — the register map is the contract between hardware and the driver team

### The interview version

> "APB is the simplest AMBA bus, which made it the right one to implement first. The point wasn't protocol difficulty — it's that a bare UART is a component and a register-mapped UART is something an SoC integrator can actually use. The register map is a contract with the firmware team."

### What you'd need to add for production

AXI rather than APB for anything high-throughput. Backpressure handling. A proper interrupt line rather than a polled STATUS bit. A receive FIFO, because dropping bytes when software is slow is not acceptable. Formal verification of protocol compliance — there are commercial assertion IP packages (Cadence, Siemens) that do exactly this.

---

## 2. Clock domain crossing — Project 02

### What industry does with this

**This is one of the highest-value skills on the list, and one of the most common causes of real silicon failure.**

Any real chip has many clock domains: a CPU at one frequency, a memory interface at another, a display pipeline at a third, peripherals at slow fixed rates, and power management dynamically scaling several of them. Data crosses between them constantly.

CDC bugs are notorious because they are **intermittent, temperature-dependent, and often not reproducible in simulation**. A design can pass a full regression suite and still fail in the field at a rate of one part in ten thousand.

### Where you'd see it

- **Every SoC integration role** — CDC review is a standing sign-off item
- **Dedicated CDC analysis tools** — Siemens Questa CDC, Synopsys SpyGlass CDC, Cadence Conformal. Companies pay six figures a seat for these.
- **Design review** — "show me your CDC report" is a standard gate before tapeout

### The interview version

> "The reason I proved the FIFO formally rather than simulating it is that CDC is exactly where simulation is structurally inadequate — a CDC bug survives thousands of cycles and fails in the field, because simulation only walks the state space it happens to walk. Gray coding is what makes the multi-bit pointer safe to synchronize; a binary counter changing four bits at once can be sampled as a value it never held."

### What you'd need to add for production

Automated CDC linting across the whole design, not one hand-proven property. Reset domain crossing analysis, which is a separate and equally nasty problem. Formal apps that check synchronizer structure automatically. Documented CDC constraints for the physical design tools, so the timing engine knows not to try to close paths that cross domains.

---

## 3. Formal verification — Projects 02, 03, 04, 06

### What industry does with this

Formal has moved from research curiosity to standard practice over the last fifteen years. Intel, ARM, AMD, Apple, NVIDIA and Qualcomm all have dedicated formal verification teams.

Typical production uses:

- **Bug hunting** on control logic — arbiters, FIFOs, state machines, cache coherence
- **Exhaustive proofs** of small critical blocks where simulation coverage is impossible
- **Connectivity checking** — proving thousands of top-level connections are correct, automatically
- **Sequential equivalence checking** — proving an optimised design matches the golden one
- **Coverage closure** — proving unreachable coverage points are genuinely unreachable, so they can be waived honestly

### Where you'd see it

- **Formal Verification Engineer** is a distinct, well-paid role
- **Design Verification (DV) Engineer** roles increasingly expect formal alongside UVM
- Tools: **Cadence JasperGold**, **Synopsys VC Formal**, **Siemens Questa Formal**. Open equivalents used here: Yosys, SymbiYosys, Boolector.

### The interview version — this is your strongest material

> "My first formal proof passed and was wrong. Unresolved hierarchical references meant the solver was checking a property structurally disconnected from the design. A vacuous proof is worse than no proof, because it manufactures confidence. Auditing every PASS for vacuity became a standing step after that, and it caught two more in the CPU project."

And the sharper one:

> "The CPU's own block-level proof compared `branch_taken` against a reference computed in the bind file — from the same ALU result, with the same case statement. That catches typos. It cannot catch a misreading of the spec, because both sides are wrong together. riscv-formal compares against the ISA, and it found a trap bug that proof had passed over for months."

**Why that lands:** the distinction between proving a design self-consistent and proving it specification-conformant is something many engineers with formal on their résumé have never articulated. Being able to explain it with a concrete bug you found puts you ahead of people with more years of exposure.

### What you'd need to add for production

SystemVerilog Assertions (SVA) rather than hand-written property modules — SVA is the industry language and JasperGold's native input. Abstraction techniques for state-space explosion. Proof decomposition and helper lemmas. Knowing when formal is the *wrong* tool, which is most of the time on large datapaths.

---

## 4. Processor design and ISA conformance — Project 04

### What industry does with this

RISC-V has gone from academic project to a major commercial ISA in roughly a decade. SiFive, Andes, Codasip, Ventana and Tenstorrent build RISC-V cores commercially; Western Digital, NVIDIA, Qualcomm and Google all ship RISC-V cores inside larger chips as controllers and accelerator front-ends.

**ISA conformance verification is a real, funded discipline.** RISC-V International runs a compliance/architectural-test working group precisely because "we implemented the spec" is a claim that needs checking.

### Where you'd see it

- **CPU design and verification** at any RISC-V vendor
- **`riscv-formal` specifically** — Clifford Wolf's framework is used in production; it is not a toy
- **RVFI** is a de-facto standard trace interface that commercial cores implement
- **TestRIG / RVFI-DII** — the Cambridge/CHERI toolchain for differential testing against a reference model

### The interview version

> "The CPU ran a compiled C bubble-sort correctly end to end, and it still had a specification bug. riscv-formal found it in seconds: RV32I raises a misaligned-instruction-address trap based on the branch's computed target whether or not the branch is taken, and I'd gated it on `branch_taken`. A not-taken branch from an already-misaligned PC inherits the misalignment through `pc + 4`. No directed test would ever construct that state."

### What you'd need to add for production

A pipeline, which makes RVFI substantially harder — you must track values to writeback and get `rvfi_order` right across flushes and stalls. Exception and interrupt handling. CSRs and privilege modes. Caches, and cache coherence if multicore. Then the same conformance argument at every one of those layers.

---

## 5. Physical design and timing closure — Projects 05, 07

### What industry does with this

This is where most of the headcount is at a large chip company, and where the schedule usually slips.

A physical design engineer takes synthesised RTL and produces a manufacturable layout that meets timing, power and area targets across every corner. The work is iterative: floorplan, place, route, analyse, find violations, fix, repeat — often for months.

**Timing closure is the recurring crisis of every tapeout.** Being the person who can read a timing report and say "this path fails because of X, and the fix is Y" is directly valuable.

### Where you'd see it

- **Physical Design Engineer** / **STA Engineer** — large teams at Apple, Intel, AMD, NVIDIA, Qualcomm, Broadcom, and every foundry-adjacent design house
- Tools: **Synopsys ICC2 / Fusion Compiler**, **Cadence Innovus**, **Synopsys PrimeTime** for sign-off STA. Open equivalents used here: OpenROAD, OpenSTA.
- **DRC/LVS sign-off** — Siemens Calibre is the industry standard; a full-chip run can take days

### The interview version

> "Nine-corner sign-off gave 31.5 MHz worst-case against 56.3 MHz best-case — a 1.8× spread on identical silicon. That's the concrete answer to why you quote corners rather than a frequency. And I traced the gate-level critical path with OpenSTA to a named next iteration: carry-lookahead instead of ripple-carry."

Then the Tiny Tapeout story, which is the stronger one:

> "The CI reported a passing build that carried a −2.19 ns setup violation, because the shuttle's workflow doesn't fail on timing. I found it by pulling `metrics.csv` out of the build artifact rather than reading the summary page. The fix was one constraint line — but the point is that green checkmarks are not evidence."

### What you'd need to add for production

Multi-corner multi-mode (MCMM) analysis with many more than nine corners. Power analysis and IR drop. Clock tree optimisation with useful skew. Signal integrity and crosstalk. Design-for-test insertion — scan chains, ATPG, BIST — which is an entire discipline this portfolio doesn't touch and which every real chip needs.

---

## 6. Tapeout discipline — Project 07

### What industry does with this

The specific constraint — fixed die, fixed pinout, no probe access — is the everyday reality of ASIC design. Unlike an FPGA, you cannot reflash a chip. Whatever you sent to the fab is what you get, and finding out it's wrong takes months and a mask set.

That is why the design decision in this project matters more than the design:

> A serialisation FSM carries sequencing state, and sequencing state can desynchronise. On a die with no probe access there is no way to detect that from outside and no recovery short of a full reset. So: a byte-addressed register file instead, with no protocol state to lose and no illegal states.

**That reasoning — designing for the failure you cannot observe — is exactly what separates ASIC thinking from FPGA thinking.**

### Where you'd see it

- **Design for Test (DFT)** — the whole discipline exists because you can't probe a packaged part
- **Bring-up engineering** — the team that gets first silicon working, whose life is made or ruined by whether the design was made observable
- **Post-silicon validation** — correlating measured behaviour against simulation, which is exactly the May 2027 work item

### The interview version

> "The interesting problem wasn't the ALU, it was the interface: 101 signals through 24 pins on a die I can't probe. I rejected the obvious serialisation FSM because sequencing state can desynchronise with no way to detect it and no recovery path. The byte-addressed register file costs 68 flip-flops and buys me a design with no illegal states."

---

## 7. Research reimplementation — Project 06

### What industry does with this

Less directly than the others, and that's worth being honest about. Polynomial formal verification is an active research area, not a production technique.

Where it *does* connect:

- **Advanced verification R&D** at large companies — Intel, IBM and NVIDIA all publish in this space
- **EDA vendor research** — the algorithms in JasperGold come from exactly this kind of work
- **Academic research** — this is a PhD-shaped project

### The interview version

Frame it by what it demonstrates rather than by its applicability:

> "I read a DATE 2024 paper, reimplemented its methodology against my own ALU with entirely open tooling, reproduced six of the published node counts, re-derived the O(n²) bound from measurement, and corrected two of my own earlier explanations where the measurements contradicted them. The paper is under-specified about its counting convention rather than wrong. The variable-ordering result is the memorable one: interleaved ordering finishes in seconds, grouped ordering exhausts 7 GB and gets OOM-killed. Same function, same tool, same machine."

**Where to lead with this:** graduate applications, research roles, and any conversation with someone who has a PhD. **Where not to:** a physical design interview at a product company, where it reads as a distraction from the timing work they actually care about.

---

## Role-by-role: which projects to lead with

| Role | Lead with | Then | Skip or downplay |
|---|---|---|---|
| **RTL Design Engineer** | 04 (CPU), 01 (bus interface) | 03, 02 | 06 |
| **Design Verification Engineer** | 04 (riscv-formal bug), 02 (vacuous proof) | 03, 07 test suite | 05 |
| **Formal Verification Engineer** | 02, 04, 06 | 03 | 01 |
| **Physical Design / STA** | 05 (nine corners), 07 (hidden violation) | 04 | 06, 01 |
| **SoC Integration** | 01 (APB), 04 (SoC refactor) | 02 (CDC) | 06 |
| **PhD application (verification)** | 06, then 04 | 02 | 01 |
| **General new-grad hardware** | 07 (tapeout), 04 (runs C) | 05 | — |

---

## The four stories that do the most work

Regardless of role, these are the ones worth having ready. Each is a *finding*, not a description — which is why they survive follow-up questions.

**1. The vacuous proof.** "My first formal proof passed and was checking nothing." → demonstrates verification maturity and intellectual honesty.

**2. The self-referential proof.** "My branch proof compared the design against a copy of its own logic; riscv-formal compared it against the spec and found a real bug." → demonstrates you understand what verification claims actually mean.

**3. The hidden timing violation.** "CI said green; there was a −2.19 ns setup violation in `metrics.csv`." → demonstrates you don't trust tools you haven't audited.

**4. The interface decision.** "I rejected a serialisation FSM because on an unprobeable die, sequencing state has no recovery path." → demonstrates design reasoning under real constraints rather than pattern-matching.

---

## What this portfolio still cannot claim

Say these before someone asks. Volunteering a limitation is worth more than defending against one.

- **No pipelined design.** Single-cycle avoids hazards, forwarding and stalls entirely — the hard parts of CPU design.
- **No UVM.** Industry DV runs on UVM and constrained-random SystemVerilog; this portfolio uses cocotb and hand-written testbenches.
- **No DFT.** No scan chains, no ATPG, no BIST. Every production chip needs these.
- **No power analysis.** Not a single power number anywhere in the portfolio.
- **No measured silicon yet.** The Tiny Tapeout die returns May 2027. Until then, everything is verified, not measured.
- **Small scale.** 1,602 standard cells. Production blocks are millions.

The right posture: these are the next rungs, and knowing which rung you're on is itself a signal.

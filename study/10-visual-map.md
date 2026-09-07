# Visual map — what the project chain teaches

Diagrams render directly on GitHub. If you're reading this in a plain text editor, the Mermaid blocks are still readable as structured text.

---

## 1. The dependency graph

Projects aren't independent. One artefact — the ALU — threads through five of them.

```mermaid
graph TD
    P1["01 · UART / APB<br/>peripheral + bus interface"]
    P2["02 · Async FIFO<br/>CDC + first formal proof"]
    P3["03 · RV32I ALU<br/>formally verified"]
    P4["04 · RV32I CPU<br/>runs compiled C"]
    P5["05 · Physical Design<br/>RTL to GDSII"]
    P6["06 · PFV research<br/>DATE 2024"]
    P7["07 · Tiny Tapeout<br/>real wafer"]
    SIL["May 2027<br/>measured silicon"]

    P1 -->|"synchronizer idea"| P2
    P2 -->|"formal technique<br/>+ vacuity lesson"| P3
    P3 -->|"the ALU block"| P4
    P3 -->|"the ALU block"| P5
    P3 -->|"the ALU block"| P6
    P5 -->|"hardening flow"| P7
    P3 -->|"the ALU block"| P7
    P4 -->|"CPU as future payload"| P7
    P7 --> SIL

    style P3 fill:#2d4a2d,stroke:#5a9,color:#fff
    style P4 fill:#2d3a5a,stroke:#69f,color:#fff
    style P7 fill:#5a3a2d,stroke:#f95,color:#fff
    style SIL fill:#1a1a1a,stroke:#666,color:#999,stroke-dasharray: 5 5
```

**Read this as:** Project 03's ALU is the spine. It gets integrated (04), hardened (05), researched (06) and fabricated (07). Everything else is either a prerequisite skill or a consequence of it.

---

## 2. The abstraction ladder

Each project sits at a different level of "how real is this?"

```mermaid
graph BT
    A["Behaviour<br/><i>does it compute the right answer?</i>"]
    B["Timing<br/><i>does it compute it in time?</i>"]
    C["Geometry<br/><i>can it be manufactured?</i>"]
    D["Silicon<br/><i>does the physical part do it?</i>"]

    A --> B --> C --> D

    A -.-> A1["01 · simulation<br/>02 · formal CDC proof<br/>03 · formal equivalence<br/>04 · ISA conformance<br/>06 · BDD equivalence"]
    B -.-> B1["05 · nine-corner STA<br/>07 · setup +0.425 / hold +0.117"]
    C -.-> C1["05 · DRC / LVS / antenna clean<br/>07 · DRC / LVS / antenna clean"]
    D -.-> D1["07 · fabricated die<br/><b>returns May 2027</b>"]

    style D fill:#1a1a1a,stroke:#666,color:#999
    style D1 fill:#1a1a1a,stroke:#666,color:#999,stroke-dasharray: 5 5
```

**The point:** most portfolios stop at the bottom layer. This one reaches the third and has the fourth scheduled. Each layer can pass while the one above fails — a design can be functionally perfect and fail timing, or meet timing and violate DRC.

---

## 3. The verification ladder — the actual intellectual arc

This is the most important diagram here. It's the story of *how confidence was earned*, and each rung was learned by being burned on the one below.

```mermaid
graph TD
    L1["<b>1 · Directed simulation</b><br/>Project 01<br/>4 patterns, all pass"]
    Q1{"But what about<br/>the inputs I<br/>didn't try?"}

    L2["<b>2 · Formal proof</b><br/>Project 02<br/>no_overflow, depth 20"]
    Q2{"The proof passed…<br/>and was checking<br/>nothing"}

    L3["<b>3 · Non-vacuous formal</b><br/>Projects 02 fixed, 03<br/>audit every PASS"]
    Q3{"Proven against<br/>what reference,<br/>exactly?"}

    L4["<b>4 · Proof vs. spec</b><br/>Project 04<br/>riscv-formal, 43/43"]
    Q4{"Does the physical<br/>part actually<br/>do this?"}

    L5["<b>5 · Measured silicon</b><br/>May 2027<br/><i>not yet done</i>"]

    L1 --> Q1 --> L2 --> Q2 --> L3 --> Q3 --> L4 --> Q4 --> L5

    style L2 fill:#5a2d2d,stroke:#f66,color:#fff
    style L4 fill:#2d4a2d,stroke:#5a9,color:#fff
    style L5 fill:#1a1a1a,stroke:#666,color:#999,stroke-dasharray: 5 5
```

**Each arrow is a question the previous rung couldn't answer.** That's what makes it a ladder rather than a list.

---

## 4. Vacuity — three times, three disguises

The recurring failure. Same root cause every time.

```mermaid
graph LR
    R["<b>Root cause</b><br/>hierarchical dot-paths<br/>into a flattened design"]

    V1["<b>1 · Project 02</b><br/>Unresolved refs →<br/>property disconnected<br/>from the FIFO"]
    V2["<b>2 · Project 04</b><br/>Two more vacuous<br/>proofs, caught by<br/>the standing audit"]
    V3["<b>3 · Project 04</b><br/>Debug taps read<br/>dump-time constants.<br/>Zero warnings."]

    F["<b>The defence</b><br/>Observe through<br/>real module ports.<br/>A port can't silently<br/>disconnect."]

    R --> V1 --> V2 --> V3 --> F

    style R fill:#5a2d2d,stroke:#f66,color:#fff
    style F fill:#2d4a2d,stroke:#5a9,color:#fff
```

The third one is the most instructive: the defence was already written in this project's own `pc_bind.sv` header comment — *"no dot-paths, avoiding the vacuous-proof issue"* — and the same mistake was still made from the wrapper side. Knowing a lesson and having it structurally enforced are different things.

---

## 5. Why riscv-formal found what nothing else could

The single strongest result in the portfolio, drawn as a comparison.

```mermaid
graph TD
    subgraph SELF["Self-referential proof · pc_bind.sv"]
        D1["Design computes<br/>branch_taken from<br/>alu_result"]
        R1["Reference re-derives<br/>branch_taken from<br/>the SAME alu_result<br/>with the SAME case stmt"]
        C1{"Compare"}
        D1 --> C1
        R1 --> C1
        C1 --> O1["Catches typos ✓<br/>Catches spec errors ✗<br/><i>both sides wrong together</i>"]
    end

    subgraph SPEC["Spec conformance · riscv-formal"]
        D2["Design retires<br/>an instruction,<br/>reports via RVFI"]
        R2["Independent model<br/>of the RISC-V ISA"]
        C2{"Compare"}
        D2 --> C2
        R2 --> C2
        C2 --> O2["Found the bug ✓<br/><i>trap gated on branch_taken<br/>should be branch</i>"]
    end

    style O1 fill:#5a2d2d,stroke:#f66,color:#fff
    style O2 fill:#2d4a2d,stroke:#5a9,color:#fff
```

---

## 6. The bug itself, as a state walk

Worth being able to draw this on a whiteboard.

```mermaid
graph LR
    S1["PC = ...1010<br/><b>already misaligned</b>"]
    S2["Execute BEQ<br/>rs1 ≠ rs2<br/><b>not taken</b>"]
    S3["pc_next = pc + 4<br/>= ...1110<br/><b>still misaligned</b>"]
    S4["Spec: trap ✓<br/>Core: no trap ✗"]

    S1 --> S2 --> S3 --> S4

    style S1 fill:#5a3a2d,stroke:#f95,color:#fff
    style S4 fill:#5a2d2d,stroke:#f66,color:#fff
```

**Why every other method missed it:**

| Method | Why it missed |
|---|---|
| Compiled C bubble-sort | Real code never runs from a misaligned PC |
| Directed tests | Nobody writes a test that starts misaligned *and* uses a not-taken branch |
| `pc_bind.sv` proof | Re-derives the same condition from the same signals |
| Gate-level sim | Same stimulus as RTL — same blind spot |
| riscv-formal | Solver picks any legal PC, including misaligned ones ✓ |

---

## 7. Project 05 vs Project 07 — what a clock tree costs

The same RTL, hardened twice under different constraints. This is a controlled experiment, which is rare in a portfolio.

```mermaid
graph TD
    RTL["<b>The same ALU RTL</b><br/>formally verified in Project 03"]

    P5["<b>Project 05</b><br/>free floorplan<br/>purely combinational"]
    P7["<b>Project 07</b><br/>fixed 1×1 tile<br/>+ 68 flip-flops"]

    RTL --> P5
    RTL --> P7

    P5 --> M5["No clock tree<br/>Skew = 0<br/>Reg-to-reg = ∞<br/>9 corners: 31.5–56.3 MHz"]
    P7 --> M7["117 clock buffers<br/>Skew = 0.255 ns<br/>Reg-to-reg = +10.49 ns<br/>Setup +0.425 / Hold +0.117"]

    M5 --> DELTA["<b>The delta is what a<br/>clock tree costs</b><br/><i>caveat: partly constraint-driven,<br/>not purely design-driven</i>"]
    M7 --> DELTA

    style RTL fill:#2d4a2d,stroke:#5a9,color:#fff
    style DELTA fill:#2d3a5a,stroke:#69f,color:#fff
```

The caveat in that last box matters. Flagging that part of the difference comes from the clock *constraint* rather than the clock *tree* is what makes the rest of the comparison credible. Isolating it would mean re-running Project 05 at 25 ns on a fixed die.

---

## 8. The Tiny Tapeout interface problem

101 signals, 24 pins, and the reasoning that picked the solution.

```mermaid
graph TD
    PROB["<b>101 signals → 24 pins</b><br/>68 in (a, b, alu_op)<br/>33 out (result, zero)<br/>4× oversubscribed"]

    OPT1["<b>Option A</b><br/>Serialisation FSM<br/>shift bytes behind<br/>a handshake"]
    OPT2["<b>Option B</b><br/>Byte-addressed<br/>register file"]

    PROB --> OPT1
    PROB --> OPT2

    OPT1 --> RISK["<b>Rejected</b><br/>FSM carries sequencing state.<br/>State can desynchronise.<br/>No probe access on a die →<br/>can't detect it, can't recover."]

    OPT2 --> WIN["<b>Chosen</b><br/>No protocol state to lose.<br/>No illegal states — no<br/>sequence is being tracked.<br/>Cost: 68 flip-flops."]

    WIN --> CONSEQ["<b>Consequence</b><br/>Combinational block becomes<br/>sequential → real clock tree,<br/>hold analysis, and the<br/>accumulate reg-to-reg arc"]

    style RISK fill:#5a2d2d,stroke:#f66,color:#fff
    style WIN fill:#2d4a2d,stroke:#5a9,color:#fff
```

---

## 9. The green-checkmark trap

```mermaid
graph LR
    BUILD["Hardened build<br/>completes"]
    CI["<b>CI: PASS ✓</b><br/>DRC clean<br/>LVS clean<br/>Antenna clean<br/>10/10 gate-level tests"]
    HIDDEN["<b>Hidden in metrics.csv</b><br/>setup slack = −2.19 ns<br/><i>CI doesn't fail on timing</i>"]
    FIX["Traced to<br/>a_reg → ALU → mux → pad<br/>22.2 ns vs 20 ns constraint"]
    RESULT["CLOCK_PERIOD 20 → 25 ns<br/>Final: +0.425 ns<br/>(1.7% margin)"]

    BUILD --> CI
    BUILD --> HIDDEN
    HIDDEN --> FIX --> RESULT

    style CI fill:#2d4a2d,stroke:#5a9,color:#fff
    style HIDDEN fill:#5a2d2d,stroke:#f66,color:#fff
```

**The transferable lesson:** know what your CI actually checks. A passing pipeline is evidence about the checks that ran, not about the design.

---

## 10. Skills accumulated, by project

```mermaid
graph LR
    subgraph "RTL & Design"
        A1["FSM design"]
        A2["Bus protocols · APB"]
        A3["CDC architecture"]
        A4["Datapath design"]
        A5["Processor microarchitecture"]
    end
    subgraph "Verification"
        B1["Directed simulation"]
        B2["Formal · BMC"]
        B3["Vacuity auditing"]
        B4["ISA conformance · RVFI"]
        B5["Gate-level sim"]
        B6["cocotb"]
    end
    subgraph "Physical"
        C1["Synthesis"]
        C2["Place & route"]
        C3["STA · multi-corner"]
        C4["DRC / LVS / antenna"]
        C5["Fixed-die tapeout"]
    end
    subgraph "Research"
        D1["Paper reimplementation"]
        D2["BDD equivalence"]
        D3["Complexity measurement"]
    end
```

| Project | Adds |
|---|---|
| 01 | FSM design, APB, oversampling, FPGA flow, first synchronizer |
| 02 | CDC architecture, Gray code, formal BMC, **vacuity** |
| 03 | Exhaustive formal equivalence on a datapath |
| 04 | Integration, cross-toolchain build, RVFI, **ISA conformance** |
| 05 | Full RTL-to-GDSII, multi-corner STA, physical verification |
| 06 | Research reimplementation, BDD ordering, complexity measurement |
| 07 | Fixed-die constraints, clock tree, cocotb, **auditing CI** |

---

## 11. What's finished and what isn't

```mermaid
graph TD
    DONE["<b>Complete</b><br/>01 · 02 · 03 · 04 · 05 · 06 · 07 design"]
    PEND["<b>Pending</b><br/>07 shuttle submission<br/>TTSKY26c payment"]
    FUT1["<b>May 2027</b><br/>Silicon correlation:<br/>134 vectors vs the die"]
    FUT2["<b>Next project</b><br/>RVFI-DII / TestRIG<br/>instruction injection"]
    FUT3["<b>Open</b><br/>Isolate the P05/P07<br/>constraint confound"]

    DONE --> PEND --> FUT1
    DONE --> FUT2
    DONE --> FUT3

    style DONE fill:#2d4a2d,stroke:#5a9,color:#fff
    style PEND fill:#5a3a2d,stroke:#f95,color:#fff
    style FUT1 fill:#1a1a1a,stroke:#666,color:#999,stroke-dasharray: 5 5
    style FUT2 fill:#1a1a1a,stroke:#666,color:#999,stroke-dasharray: 5 5
    style FUT3 fill:#1a1a1a,stroke:#666,color:#999,stroke-dasharray: 5 5
```

---

## The whole thing in one sentence

**One arithmetic block — written once, proven against an independent model, integrated into a processor that runs compiled C, proven again against the ISA where a real bug surfaced that neither simulation nor self-referential proof could see, hardened to routed silicon twice under different physical constraints, studied as the subject of a research reimplementation that corrected two of the original paper's claims, and sent to a shuttle that returns it as a fabricated die.**

Plus three separate occasions where verification appeared to succeed while checking nothing — each caught, and each one changing how the next proof was written.

# Study guide — FPGA / RTL portfolio

Documentation for reconstructing this portfolio's work from memory: what was built, why it was built in this order, and the concepts underneath it.

## Read in this order

| # | Document | Read it when |
|---|---|---|
| 00 | [Fundamentals](00-fundamentals.md) | A term in a project doc is unfamiliar, or you want the concepts underneath everything |
| 01 | [Why these projects, in this order](01-rationale.md) | You want the argument for the sequence — the answer to "why this portfolio and not seven random projects" |
| 02 | [Project 01 — UART / APB](02-project01-uart.md) | |
| 03 | [Project 02 — Async FIFO](03-project02-async-fifo.md) | |
| 04 | [Project 03 — RV32I ALU](04-project03-rv32i-alu.md) | |
| 05 | [Project 04 — RV32I CPU](05-project04-rv32i-cpu.md) | |
| 06 | [Project 05 — Physical Design](06-project05-physical-design.md) | |
| 07 | [Project 06 — Polynomial Formal Verification](07-project06-pfv.md) | |
| 08 | [Project 07 — Tiny Tapeout](08-project07-tiny-tapeout.md) | |
| 09 | [Where this maps in the real world](09-real-world-applications.md) | Before any interview — what each skill is used for in industry, which projects to lead with per role, and what this portfolio still can't claim |
| 10 | [Visual map of the chain](10-visual-map.md) | You want the whole thing as diagrams — dependency graph, verification ladder, and the bug drawn as a state walk |

## Preparing for an interview

Read **01 (rationale)** first — it gives you the one-paragraph version of the whole portfolio and the through-line between projects. Then read the project document for whatever they asked about, and check you can answer its "Questions you should be able to answer" section without looking.

If you have twenty minutes, read **10 (visual map)** for the shape, then **09 (real-world)** for the role-specific framing and the four stories that do the most work. If you have an hour, add the Project 04 and Project 07 documents — those two carry the strongest material.

Doc 09 has a role-by-role table telling you which projects to lead with and which to downplay depending on whether you're talking to a physical design team, a DV team, or a PhD supervisor.

## The three things worth leading with

1. **riscv-formal found a real bug** in the CPU that a passing bubble-sort and four passing block-level proofs both missed — because those proofs compared the design against itself.
2. **A green CI run hid a −2.19 ns setup violation**, found by reading `metrics.csv` instead of the summary page.
3. **Three separate vacuous proofs** were caught across the portfolio, each one changing how the next proof was written.

None of those is "I built a thing." All three are "I know how verification lies to you."

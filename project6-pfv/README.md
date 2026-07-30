# Modern Processor Design — Interview Study Guide

> An interview-prep companion to Shen & Lipasti's *Modern Processor Design: Fundamentals of Superscalar Processors*. The 658-page graduate textbook, distilled into 11 chapters of concept summaries and 146 interview Q&A.

**🔗 Live: [vutukuribanurohit02.github.io/processor-design-study](https://vutukuribanurohit02.github.io/processor-design-study/)**

Built for students and new grads targeting **RTL Design Verification, SoC Integration, Physical Design, and CPU architecture roles** at companies like Apple, NVIDIA, AMD, Qualcomm, Intel, Cirrus Logic, and Tenstorrent.

---

## What's inside

**11 chapters covering the full book**

| # | Chapter | Topics |
|---|---------|--------|
| 01 | Processor Design | ISA, dynamic-static interface, performance equation |
| 02 | Pipelined Processors | Hazards, forwarding, balancing stages, MIPS R2000 |
| 03 | Memory & I/O | Caches, virtual memory, TLBs, AMAT, DMA |
| 04 | Superscalar Organization | Parallel/diversified/dynamic pipelines |
| 05 | Superscalar Techniques | Tomasulo, register renaming, ROB, load-store ordering |
| 06 | PowerPC 620 | End-to-end OoO case study with measurements |
| 07 | Intel P6 | uops, RAT, ROB, the architecture behind Pentium Pro through modern Intel |
| 08 | Survey of Designs | Speed demons vs brainiacs, Alpha, MIPS, x86-64, SPARC |
| 09 | Branch Prediction | gshare, TAGE, perceptron, BTB, RAS, trace cache |
| 10 | Value Prediction | Value locality, instruction reuse, beyond data flow |
| 11 | Multithreading & CMP | SMT, MESI/MOESI, sequential consistency vs TSO vs relaxed, LL/SC vs CAS |

Plus a one-page cheat sheet and 35-question rapid-fire round for the night before an interview.

---

## Three modes

- **Read mode** — Chapter-by-chapter reading. Toggle Single Page or All Chapters. Print-friendly.
- **Quiz mode** — 10 random questions from the full pool of 146. Score yourself, repeat.
- **Flashcard mode** — Flip-card drills across the whole deck. Mark known cards to skip on next pass.

Plus live search across every Q&A, progress tracking, and a stats panel showing chapters viewed, questions opened, quiz scores, and time on page.

---

## Why this exists

I built this while prepping for my own ASIC/RTL Design Verification interviews. The Shen & Lipasti textbook is the standard for graduate computer architecture, but at 658 pages it's hard to revisit a week before an interview. I needed something that gave me the same depth in a format I could drill, search, and quiz against.

If you're a student or new grad in the same situation, this should save you a few weeks of synthesis work.

---

## Tech notes

- **Single static HTML file** — no build step, no framework, no dependencies. Works offline once loaded.
- **No tracking, no login, no ads.** All progress stored in browser `localStorage`.
- **Hosted on GitHub Pages.** Source is this repo.
- **~250 KB** total page size. Loads in under a second on most connections.
- **Mobile-responsive.** Same experience on phone, tablet, laptop.

The site is intentionally simple in implementation but careful in content — every concept was checked against the textbook source, with corrections to common online summaries (e.g. PowerPC 620's reservation-station configuration, Pentium Pro's 4-1-1 decode rules).

---

## How to use this guide

**Three-pass method works best:**

1. **Skim** — read the lede and section headers of each chapter. Build a mental map. (~30 min/chapter)
2. **Deep read** — work through formulas with pencil and paper. Try every Q&A before opening it. (~1–2 hr/chapter)
3. **Active recall** — close the page, explain the chapter aloud in 2 minutes. The places you stumble are exactly where an interviewer will probe.

**One-week interview prep priority order:**
Ch 2 (pipelining) → Ch 5 (OoO techniques) → Ch 3 (memory) → Ch 9 (branch prediction) → Ch 4 (organization) → Ch 11 (multithreading) → fill in remaining chapters.

---

## Feedback welcome

Found an error? Have a suggestion? Open an [issue](https://github.com/Vutukuribanurohit02/processor-design-study/issues) or message me on LinkedIn.

---

## Author

**Banu Rohit Vutukuri** — MS Electrical Engineering (Computer & Embedded Systems), University of Houston · December 2025.

Targeting RTL Design Verification, SoC Integration, and Physical Design roles.

[LinkedIn](https://www.linkedin.com/in/banurohit-vutukuri/) · [GitHub](https://github.com/Vutukuribanurohit02) · vutukuribanurohit02@gmail.com

---

## Citation

This guide is a study companion to:

> Shen, J. P., & Lipasti, M. H. *Modern Processor Design: Fundamentals of Superscalar Processors.* Waveland Press.

All concepts and frameworks are credited to the original authors. This guide adds interview-focused synthesis, modern (2024–2025) processor examples, and an interactive presentation. **Buy the textbook** if you want the full depth — it remains the best superscalar architecture text in print.

---

*Made while interview-prepping. If it helps you land a role, drop a note — I'd love to hear.*

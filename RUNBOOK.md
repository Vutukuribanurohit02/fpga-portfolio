# Portfolio runbook — how to re-run everything

Verified working on 13 Sep 2026. All paths are on the WSL side unless stated.

## Before anything

Two environments, and most failures today came from being in the wrong one.

```bash
wsl                 # from PowerShell
formal              # sources the OSS CAD Suite
```

Your prompt should read `(OSS CAD Suite) (hdl)`. If it only shows `(hdl)`,
`sby`, `yosys` and `iverilog` are not on the path and everything formal will
fail with "command not found".

Everything lives in `~/work/`:

```
~/work/fpga-portfolio/     projects 1-6 plus the site
~/work/tt-alu/             project 7 (separate repo, separate remote)
~/work/riscv-formal/       the ISA checker, points at project 4's RTL
```

---

## Project 01 — UART / APB

RTL is in `project1-uart/rtl/`. The Vivado project is on the **Windows** side:

```
C:\Users\vutuk\OneDrive\Documents\fpga-portfolio\project1-uart\uart_apb_project\
```

Open `uart_apb_project.xpr` in Vivado 2018.2 to re-run synthesis,
implementation or bitstream generation. Reports land in
`uart_apb_project.runs/impl_1/`.

To read the last run's numbers without opening Vivado:

```bash
V=/mnt/c/Users/vutuk/OneDrive/Documents/fpga-portfolio/project1-uart/uart_apb_project/uart_apb_project.runs/impl_1
grep -A8 "Design Timing Summary" $V/nexys_uart_top_timing_summary_routed.rpt | tail -4
grep -E "^\| (Slice )?LUTs|^\| (Slice )?Registers|^\| Block RAM|^\| Bonded IOB" $V/nexys_uart_top_utilization_placed.rpt
```

---

## Project 02 — Async FIFO, formal CDC proof

```bash
formal && cd ~/work/fpga-portfolio/project2-async-fifo/formal && sby -f fifo.sby 2>&1 | tail -6
```

`-f` forces a clean re-run. Without it, sby refuses to overwrite the existing
`fifo/` directory. Takes under a second.

The proof reads `fifo_bind.sv` (one assertion, `occupancy <= DEPTH`) bound
against `../rtl/`.

---

## Project 03 — RV32I ALU, 11 properties

```bash
formal && cd ~/work/fpga-portfolio/project3-rv32i-alu/formal && sby -f alu.sby 2>&1 | tail -8
```

Same pattern. The eleven properties are in `alu_bind.sv` lines 32-53.
SBY reports one task (`[alu] DONE (PASS)`), not eleven — all eleven
assertions live inside that single check.

---

## Project 04 — RV32I CPU

**Run the bubble sort** (prebuilt binary, no compile needed):

```bash
cd ~/work/fpga-portfolio/project4-rv32i-cpu/sim && ./cpu_tb 2>&1 | tail -30
```

If you ever need to rebuild `cpu_tb`, check the project README for the
iverilog line — I didn't verify the build command, only that the binary runs.

**riscv-formal, all 43 checks:**

```bash
formal && cd ~/work/riscv-formal/cores/rv32i && make -C checks -j4
grep -h DONE checks/*/logfile.txt | awk '{p+=/PASS/} END{print p"/"NR" PASS"}'
```

Note: `make` will say *nothing to be done* if the check directories already
exist. To genuinely re-run, delete them first: `rm -rf checks/insn_*_ch0`.

**Differential testing:**

```bash
cd ~/work/fpga-portfolio/project4-rv32i-cpu/dii
python3 fuzz.py -n 2000 -l 60        # the 164,000-instruction run, ~6 s
python3 fuzz.py -n 50 -l 30          # quick smoke
python3 fuzz.py --replay <hexfile>   # re-run one saved sequence
```

Flags: `-n` sequences, `-l` instructions per sequence, `--seed`, `--replay`.
Each sequence is a 22-instruction prelude (LUI/ADDI across x1-x11) plus `-l`
generated, so `-n 2000 -l 60` is 2,000 x 82 = 164,000.

---

## Project 05 — RTL-to-GDSII

The LibreLane flow config is **not committed** — it lives outside the repo.
What is committed: `alu.gds`, `metrics/`, and the render scripts in `config/`.

To re-read the signed-off numbers without re-running the flow:

```bash
cd ~/work/fpga-portfolio/project5-physical-design
python3 -c "import json;d=json.load(open('metrics/metrics_33ns.json'));print(json.dumps({k:v for k,v in d.items() if 'die__area' in k or 'instance__count' in k or 'utilization' in k or 'drc' in k.lower() or 'lvs' in k.lower()},indent=2))"
```

`config/sweep.sh` is the clock-constraint sweep that proved the critical path
is a fixed 31.733 ns. Re-running the full flow needs the config file rebuilt
first — worth doing once and committing it, so this project is reproducible.

---

## Project 06 — Polynomial Formal Verification

```bash
cd ~/work/fpga-portfolio/project6-pfv/scripts
nix-shell --run "./extract.sh and"      # AIG extraction for one opcode
python3 profile2.py and                 # BDD build + node counts
./run_all.sh                            # both, for every confirmed opcode
```

Confirmed opcodes: `and`, `xor`, `add`. `profile2.py` re-execs itself with
`PYTHONHASHSEED=0` — run it directly, don't source a different venv first, or
the node counts stop being reproducible.

---

## Project 07 — Tiny Tapeout ALU

Separate repo at `~/work/tt-alu/`.

```bash
cd ~/work/tt-alu/test && rm -rf sim_build results.xml && make 2>&1 | tail -20
```

The `rm -rf sim_build` matters. A stale build from an older Icarus gives
`VVP input file 12.0 can not be run with run time version 14.0`.

Expect `TESTS=10 PASS=10 FAIL=0`. A segfault after the summary is Icarus
crashing while closing the FST dumpfile — it happens after every test has
already passed, and it makes `make` delete `results.xml`. Harmless.

**Waveform:**

```bash
gtkwave ~/work/tt-alu/test/tb.gtkw &
```

`tb.gtkw` is a saved session, so the signal list comes up already configured.
Needs an X server under WSL.

**Hardening** runs in GitHub Actions on push to `main` — no local toolchain
required. `test` runs cocotb, `gds` runs LibreLane plus gate-level re-test,
`docs` publishes the datasheet.

---

## The site

```bash
cd ~/work/fpga-portfolio && git add -A && git commit -m "..." && git push
```

GitHub Pages rebuilds from `docs/` on push. Live at
`vutukuribanurohit02.github.io/fpga-portfolio`. Give it a minute or two.

To preview locally before pushing:

```bash
explorer.exe "file://wsl.localhost/Ubuntu/home/vutukuribanurohit02/work/fpga-portfolio/docs/index.html"
```

---

## Known gaps

- `project4-rv32i-cpu/dii/` has no README
- Project 05's LibreLane config isn't committed, so the flow isn't reproducible
  from the repo alone
- `cpu_tb` rebuild command unverified

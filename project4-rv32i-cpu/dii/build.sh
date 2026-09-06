#!/bin/bash
# Build the DII harness. Run from project4-rv32i-cpu/dii/
#
# RISCV_FORMAL must be defined so the core exposes its RVFI trace port —
# that port is the entire interface this harness reads.
set -e
RTL=../rtl

verilator --cc --exe --build -j 0 \
  -DRISCV_FORMAL \
  --top-module rv32i_cpu \
  -Wno-fatal \
  -CFLAGS "-O2" \
  --Mdir obj_dir \
  -o dii_sim \
  $RTL/rv32i_cpu.sv $RTL/rv32i_alu.sv $RTL/regfile.sv \
  $RTL/decoder.sv $RTL/control.sv \
  sim_main.cpp

echo "built: obj_dir/dii_sim"

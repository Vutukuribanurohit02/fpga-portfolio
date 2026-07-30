#!/usr/bin/env bash
set -e
OP=$1
cd "$(dirname "$0")"
yosys -p "
read_verilog -sv rtl/alu.sv rtl/alu_pinned.sv
hierarchy -top alu_${OP}
proc
flatten
opt -full
techmap
opt -full
aigmap
write_aiger -ascii -symbols aig/${OP}.aag
"

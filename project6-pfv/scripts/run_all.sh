#!/usr/bin/env bash
# run_all.sh -- extract and equivalence-check every ALU opcode.
#
# Yosys lives in the LibreLane nix-shell; the BDD stack lives in a venv.
# They never share an interpreter -- Yosys writes AIGER, Python reads it.
#
#   ./run_all.sh extract    # inside: cd ~/librelane && nix-shell
#   ./run_all.sh check      # inside: source ~/pfv-rv32i/.venv/bin/activate
#   ./run_all.sh all        # check only (assumes AIGs already extracted)

set -u
cd "$(dirname "$0")/.."
OPS="add sub and or xor slt sltu sll srl sra"

case "${1:-all}" in
  extract)
    for op in $OPS; do
      echo "=== extracting $op ==="
      ./scripts/extract.sh "$op" > "logs/${op}.yosys.log" 2>&1 \
        && head -1 "aig/${op}.aag" \
        || echo "  FAILED (see logs/${op}.yosys.log)"
    done
    ;;
  check|all)
    pass=0; fail=0
    for op in $OPS; do
      if python3 scripts/equiv.py "$op" --quiet; then
        pass=$((pass+1))
      else
        fail=$((fail+1))
      fi
    done
    echo
    echo "=== $pass equivalent, $fail not equivalent ==="
    [ "$fail" -eq 0 ]
    ;;
  *)
    echo "usage: $0 {extract|check|all}"; exit 2 ;;
esac

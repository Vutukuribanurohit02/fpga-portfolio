#!/usr/bin/env bash
# run_all.sh -- extract and equivalence-check every ALU opcode.
#
# Yosys lives in the LibreLane nix-shell; the BDD stack lives in a venv.
# They never share an interpreter -- Yosys writes AIGER, Python reads it.
#
#   ./run_all.sh extract    # inside: cd ~/librelane && nix-shell
#   ./run_all.sh check      # inside: source ~/.venv/pfv/bin/activate  (pip install py-aiger py-aiger-bdd dd)
#   ./run_all.sh all        # check only (assumes AIGs already extracted)

set -u
if [ "${1:-all}" != extract ]; then
  python3 -c "import aiger, aiger_bdd, dd" 2>/dev/null || { echo "ERROR: BDD stack not importable; activate the venv. Nothing was checked." >&2; exit 2; }
fi
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
      out=$(python3 scripts/equiv.py "$op" --quiet 2>&1); rc=$?; echo "$out"
      if [ $rc -ne 0 ] && ! grep -q "NOT EQUIVALENT" <<<"$out"; then echo "ERROR $op (rc=$rc): crashed or missing input -- nothing checked" >&2; exit 2; fi
      if [ $rc -eq 0 ]; then
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

#!/bin/bash
cd /home/vutukuribanurohit02/pd-alu
for P in 32 34 40 50; do
  sed -i "s/CLOCK_PERIOD: .*/CLOCK_PERIOD: $P/" config.yaml
  python3 -m librelane --pdk-root $HOME/.ciel --run-tag alu_q$P ./config.yaml > /tmp/q$P.log 2>&1
  echo "=== $P ns ==="
  python3 - <<PYEOF
import json
try:
    d = json.load(open('runs/alu_q$P/final/metrics.json'))
    print('  ss WS:', round(float(d['timing__setup__ws__corner:max_ss_100C_1v60']),3),
          '| buffers:', d.get('design__instance__count__class:timing_repair_buffer'),
          '| area:', d.get('design__die__area'),
          '| cells:', d.get('design__instance__count__class:stdcell'))
except Exception as e:
    print('  NO METRICS:', e)
PYEOF
done

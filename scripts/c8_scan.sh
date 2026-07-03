#!/bin/bash
# Parallel C8 core module scan
SRC_DIR="/home/dtamade/projects/nextPas/core/src"
WS="/home/dtamade/projects/nextPas/.worktrees/compiler"
NEXT="$WS/build/stage0-bootstrap/nextpas"
OUT="/tmp/c8_scan"
mkdir -p "$OUT"

rm -f /tmp/c8_results.txt
touch /tmp/c8_results.txt

for f in "$SRC_DIR"/*.pas; do
  (
    base=$(basename "$f" .pas)
    outf="$OUT/${base}.txt"
    timeout 60 "$NEXT" build "$f" --target linux-x86_64 --workspace "$WS" > "$outf" 2>&1
    status=$?
    if [ $status -eq 0 ]; then
      echo "PASS $base" >> /tmp/c8_results.txt
    else
      fk=$(grep -oP 'failure-kind=\K\S+' "$outf" 2>/dev/null | head -1)
      [ -z "$fk" ] && fk="timeout-or-crash"
      echo "FAIL $base kind=$fk" >> /tmp/c8_results.txt
    fi
  ) &

  # Limit to 16 parallel
  while [ $(jobs -r | wc -l) -ge 16 ]; do
    sleep 0.1
  done
done

# Wait for all remaining
wait

echo "Total: $(wc -l < /tmp/c8_results.txt)"
echo "PASS: $(grep -c '^PASS' /tmp/c8_results.txt)"
echo "FAIL: $(grep -c '^FAIL' /tmp/c8_results.txt)"

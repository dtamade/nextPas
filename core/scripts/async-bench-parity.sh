#!/usr/bin/env bash
# async-bench-parity.sh — same-host order-of-magnitude A/B for async metrics.
# truth=same-host-order-of-magnitude; NOT API-equivalent; CI does not require this.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -d "$SCRIPT_DIR/../src" ]]; then
  CORE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
elif [[ -d "$SCRIPT_DIR/../../core/src" ]]; then
  CORE_ROOT="$(cd "$SCRIPT_DIR/../../core" && pwd)"
else
  echo "error: unable to resolve core/" >&2
  exit 2
fi

PARITY_DIR="$SCRIPT_DIR/async-bench-parity"
OUT_DIR="${ASYNC_BENCH_OUT:-$CORE_ROOT/build/async-bench-parity}"
mkdir -p "$OUT_DIR"

echo "=== async-bench-parity (same host) ==="
echo "core=$CORE_ROOT out=$OUT_DIR"
echo "truth=same-host-order-of-magnitude; not API-equivalent; not CI-gating"
echo

echo "--- nextpas test_async_bench ---"
set +e
make -C "$CORE_ROOT/tests/nextpas.core.async/test_async_bench" clean test >"$OUT_DIR/nextpas.log" 2>&1
np_rc=$?
set -e
grep -E 'metric=' "$OUT_DIR/nextpas.log" | tee "$OUT_DIR/nextpas.metrics" || true
if [[ "$np_rc" -ne 0 ]]; then
  echo "WARN: nextpas bench exit $np_rc (see $OUT_DIR/nextpas.log)" >&2
fi

if command -v go >/dev/null 2>&1; then
  echo
  echo "--- go peer ---"
  (cd "$PARITY_DIR/go" && GO111MODULE=on go run . >"$OUT_DIR/go.metrics" 2>"$OUT_DIR/go.log")
  cat "$OUT_DIR/go.metrics"
else
  echo "SKIP go: not installed"
fi

if command -v cargo >/dev/null 2>&1; then
  echo
  echo "--- rust peer ---"
  (cd "$PARITY_DIR/rust" && cargo run --release -q >"$OUT_DIR/rust.metrics" 2>"$OUT_DIR/rust.log")
  cat "$OUT_DIR/rust.metrics"
else
  echo "SKIP rust: cargo not installed"
fi


# --- dial localhost (Q19) ---
echo
echo "--- nextpas dial_ops_per_s ---"
set +e
make -C "$CORE_ROOT/tests/nextpas.core.net/test_net_async_dial_bench" clean test >"$OUT_DIR/nextpas-dial.log" 2>&1
dial_rc=$?
set -e
grep -E 'metric=' "$OUT_DIR/nextpas-dial.log" | tee "$OUT_DIR/nextpas-dial.metrics" || true
if [[ "$dial_rc" -ne 0 ]]; then
  echo "WARN: nextpas dial bench exit $dial_rc" >&2
fi

if command -v go >/dev/null 2>&1; then
  echo
  echo "--- go dial peer ---"
  (cd "$PARITY_DIR/go-dial" && GO111MODULE=on go run . >"$OUT_DIR/go-dial.metrics" 2>"$OUT_DIR/go-dial.log")
  cat "$OUT_DIR/go-dial.metrics"
fi

echo
echo "=== SCORECARD table ==="
python3 - <<'PY' "$OUT_DIR"
import re, sys
from pathlib import Path
out = Path(sys.argv[1])

def load(name):
    d = {}
    p = out / name
    if not p.exists():
        return d
    for line in p.read_text(errors="replace").splitlines():
        m = re.search(r"metric=(\S+).*?\bvalue=([0-9.eE+-]+)", line)
        if m:
            d[m.group(1)] = float(m.group(2))
    return d

np = load("nextpas.metrics") or load("nextpas.log")
npd = load("nextpas-dial.metrics") or load("nextpas-dial.log")
np.update(npd)
go = load("go.metrics")
god = load("go-dial.metrics")
go.update(god)
rs = load("rust.metrics")
keys = sorted(set(np) | set(go) | set(rs))
print("| Metric | nextpas | go peer | rust peer |")
print("|--------|---------|---------|-----------|")
for k in keys:
    def fmt(x):
        return f"{x:.1f}" if x is not None else "—"
    print(f"| `{k}` | {fmt(np.get(k))} | {fmt(go.get(k))} | {fmt(rs.get(k))} |")
print()
print("Notes: peers are std channel/mutex/timer-create shapes, not TAsyncLoop clones.")
print("truth=same-host-order-of-magnitude")
PY

echo
echo "logs: $OUT_DIR"

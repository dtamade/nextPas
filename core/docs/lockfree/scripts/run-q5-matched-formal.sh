#!/usr/bin/env bash
# Q5 formal multi-sample runner: nextpas + Go + Rust matched C1/C2.
# Usage: SAMPLES=3 ./run-q5-matched-formal.sh [output.md]
set -euo pipefail

SAMPLES="${SAMPLES:-3}"
if [[ "$SAMPLES" -lt 3 ]]; then
  echo "SAMPLES must be >= 3 for formal runs (got $SAMPLES)" >&2
  exit 1
fi

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
# scripts live at core/docs/lockfree/scripts → core is ../../..
CORE_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd -P)"
REPO_ROOT="$(CDPATH= cd -- "$CORE_ROOT/.." && pwd -P)"
BENCH_DIR="$CORE_ROOT/benchmarks/nextpas.core.lockfree/bench_lockfree"
BUILD_DIR="$CORE_ROOT/build/projects/nextpas.core.lockfree/bench_lockfree"
OUT="${1:-$CORE_ROOT/docs/lockfree/bench-results/$(date -u +%Y-%m-%d)-$(hostname -s 2>/dev/null || echo host)-q5-formal.md}"

if [[ -d /opt/fpcupdeluxe/fpc/bin/x86_64-linux ]]; then
  export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
fi

mkdir -p "$(dirname "$OUT")" "$BUILD_DIR"

echo "Building nextpas / go / rust compare binaries..."
make -C "$BENCH_DIR" build build-go-compare build-rust-compare

NP_BIN="$BUILD_DIR/bench_lockfree"
GO_BIN="$BUILD_DIR/compare_go/bench_lockfree_go"
RS_BIN="$BUILD_DIR/compare_rust/bench_lockfree_rust"

[[ -x "$NP_BIN" ]] || { echo "missing nextpas binary" >&2; exit 1; }

TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT

echo "Running SAMPLES=$SAMPLES ..."
for i in $(seq 1 "$SAMPLES"); do
  echo "  sample $i/$SAMPLES nextpas..."
  "$NP_BIN" matched >"$TMPD/np-$i.log" 2>&1 || true
  if [[ -x "$GO_BIN" ]]; then
    echo "  sample $i/$SAMPLES go..."
    "$GO_BIN" >"$TMPD/go-$i.log" 2>&1 || true
  fi
  if [[ -x "$RS_BIN" ]]; then
    echo "  sample $i/$SAMPLES rust..."
    "$RS_BIN" >"$TMPD/rs-$i.log" 2>&1 || true
  fi
done

# Parse lines containing "M ops/sec" -> scenario_key mops
# scenario_key: collapse name to first tokens before timing columns
parse_log() {
  local f="$1"
  awk '
    /M ops\/sec/ {
      mops=""
      for (i=1;i<=NF;i++) {
        if ($i=="M" && (i+1)<=NF && $(i+1) ~ /^ops/) { mops=$(i-1); break }
      }
      if (mops=="") next
      # rebuild name: fields until we hit a float that is ms (field before M ops is mops; ms is earlier)
      name=""
      for (i=1;i<=NF;i++) {
        if ($i ~ /^[0-9]+(\.[0-9]+)?$/ && $(i+1)=="ms") break
        if (name!="") name=name " "
        name=name $i
      }
      gsub(/^[[:space:]]+|[[:space:]]+$/,"",name)
      if (name!="") print name "\t" mops
    }
  ' "$f"
}

# Collect: key -> list of mops in file
: >"$TMPD/all.tsv"
for kind in np go rs; do
  for i in $(seq 1 "$SAMPLES"); do
    f="$TMPD/$kind-$i.log"
    [[ -f "$f" ]] || continue
    while IFS=$'\t' read -r name mops; do
      [[ -n "$name" && -n "$mops" ]] || continue
      printf '%s\t%s\t%s\n' "$kind" "$name" "$mops" >>"$TMPD/all.tsv"
    done < <(parse_log "$f")
  done
done

stats_line() {
  # stdin: one mops per line -> mean median min max n
  sort -n | awk '
    { a[++n]=$1; s+=$1 }
    END {
      if (n==0) { print "n/a\tn/a\tn/a\tn/a\t0"; exit }
      mean=s/n
      if (n%2) med=a[int((n+1)/2)]; else med=(a[n/2]+a[n/2+1])/2
      printf "%.3f\t%.3f\t%.3f\t%.3f\t%d", mean, med, a[1], a[n], n
    }
  '
}

DATE_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
HOST="$(hostname 2>/dev/null || echo unknown)"
OS_LINE="$(uname -srm)"
CPU_LINE="$(awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo 2>/dev/null || echo unknown)"
BUILD_ID="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
FPC_V="$(fpc -iV 2>/dev/null | head -1 || echo unknown)"

{
  echo "# Q5 formal matched results (samples≥3)"
  echo
  echo "> **Not a marketing claim.** Relative same-host comparison only."
  echo "> Absolute Mops require this envelope; re-run after significant code/hardware change."
  echo
  echo "## Envelope"
  echo
  echo '```'
  echo "date_utc:  $DATE_UTC"
  echo "host:      $HOST"
  echo "os:        $OS_LINE"
  echo "cpu:       $CPU_LINE"
  echo "compiler:  fpc $FPC_V / go / rustc -C opt-level=3"
  echo "build_id:  $BUILD_ID"
  echo "workload:  Q5 C1/C2 OPS=1e6 CAP=1024 (matched suite)"
  echo "warmup:    none (each sample cold-start process)"
  echo "measured:  wall-clock full scenario per sample"
  echo "stats:     samples=$SAMPLES mean/median/min/max"
  echo "units:     M ops/sec"
  echo "command:   SAMPLES=$SAMPLES $SCRIPT_DIR/run-q5-matched-formal.sh"
  echo '```'
  echo
  echo "## Results (M ops/sec)"
  echo
  echo "| Lang | Scenario | mean | median | min | max | n |"
  echo "|------|----------|-----:|-------:|----:|----:|--:|"

  # unique kind+name pairs
  cut -f1,2 "$TMPD/all.tsv" | sort -u | while IFS=$'\t' read -r kind name; do
    case "$kind" in
      np) lang=nextpas ;;
      go) lang=go ;;
      rs) lang=rust ;;
      *) lang=$kind ;;
    esac
    stats="$(awk -F'\t' -v k="$kind" -v n="$name" '$1==k && $2==n {print $3}' "$TMPD/all.tsv" | stats_line)"
    mean="$(echo "$stats" | cut -f1)"
    med="$(echo "$stats" | cut -f2)"
    minv="$(echo "$stats" | cut -f3)"
    maxv="$(echo "$stats" | cut -f4)"
    n="$(echo "$stats" | cut -f5)"
    echo "| $lang | $name | $mean | $med | $minv | $maxv | $n |"
  done

  echo
  echo "## Notes"
  echo
  echo "- nextpas: \`TLockFreeChannel\` C1 1P+1C / C2 2P+2C"
  echo "- go: buffered \`chan\` peers (includes historical 1T if present)"
  echo "- rust: mpsc / mutex queue peers — semantic gaps apply"
  echo "- See [bench-envelope.md](../bench-envelope.md) Q5 section."
} >"$OUT"

echo "Wrote $OUT"
cat "$OUT"

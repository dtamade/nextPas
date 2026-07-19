#!/usr/bin/env bash
# Run lightweight bench/<track> Pascal + Go pairs and print results.
#
# Usage (from repo root or any cwd):
#   bash core/docs/bench/scripts/run-scorecard-subset.sh
#   bash core/docs/bench/scripts/run-scorecard-subset.sh --tracks boolsum,fncall
#   bash core/docs/bench/scripts/run-scorecard-subset.sh --list
#   bash core/docs/bench/scripts/run-scorecard-subset.sh --tracks inttohex --summary
#
# Artifacts go under $TMPDIR/nextpas-scorecard-$$ (never core/src).
# Does not edit scorecard-subset markdown — paste/adapt stdout as needed.
#
# Exit: 0 if all PAS runs ok; 1 if any PAS failed; GO skip/fail does not fail CI
# unless SCORECARD_STRICT_GO=1.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_BENCH="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$DOCS_BENCH/../../.." && pwd)"
TRACKS_FILE="$DOCS_BENCH/scorecard-tracks.txt"
CORE_SRC="$REPO_ROOT/core/src"
BENCH_ROOT="$REPO_ROOT/bench"

TRACKS_FILTER=""
LIST_ONLY=0
SUMMARY_ONLY=0
TIMEOUT_PAS="${TIMEOUT_PAS:-180}"
TIMEOUT_GO="${TIMEOUT_GO:-120}"
STRICT_GO="${SCORECARD_STRICT_GO:-0}"

usage() {
  sed -n '2,16p' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tracks) TRACKS_FILTER="$2"; shift 2 ;;
    --list) LIST_ONLY=1; shift ;;
    --summary) SUMMARY_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ ! -d "$BENCH_ROOT" || ! -d "$CORE_SRC" ]]; then
  echo "error: expected bench/ and core/src under $REPO_ROOT" >&2
  exit 2
fi

mapfile -t ALL_TRACKS < <(grep -v '^\s*#' "$TRACKS_FILE" | grep -v '^\s*$' | sed 's/[[:space:]]//g')

if [[ -n "$TRACKS_FILTER" ]]; then
  IFS=',' read -r -a ALL_TRACKS <<< "$TRACKS_FILTER"
fi

if [[ "$LIST_ONLY" == "1" ]]; then
  printf '%s\n' "${ALL_TRACKS[@]}"
  exit 0
fi

WORKDIR="${TMPDIR:-/tmp}/nextpas-scorecard-$$"
mkdir -p "$WORKDIR/obj"
trap 'rm -rf "$WORKDIR"' EXIT

if [[ "$SUMMARY_ONLY" != "1" ]]; then
  echo "=== nextpas scorecard subset ==="
  echo "REPO=$REPO_ROOT"
  echo "WORKDIR=$WORKDIR"
  echo "tracks: ${ALL_TRACKS[*]}"
  echo ""
fi

find_pas() {
  local dir="$1"
  local f
  f=$(ls "$dir"/*_bench.pas 2>/dev/null | head -1 || true)
  if [[ -z "$f" ]]; then
    f=$(ls "$dir"/*.pas 2>/dev/null | head -1 || true)
  fi
  echo "$f"
}

run_pascal() {
  local track="$1" dir="$2" outdir="$3"
  local pas bin
  pas=$(find_pas "$dir")
  if [[ -z "$pas" ]]; then
    [[ "$SUMMARY_ONLY" == "1" ]] || echo "  PAS: no .pas found"
    return 1
  fi
  mkdir -p "$outdir"
  if ! (cd "$dir" && fpc -MObjFPC -O3 \
      -Fu"$CORE_SRC" -Fi"$CORE_SRC" \
      -FU"$WORKDIR/obj" -FE"$outdir" \
      "$(basename "$pas")" >"$outdir/fpc.log" 2>&1); then
    [[ "$SUMMARY_ONLY" == "1" ]] || { echo "  PAS: compile FAILED"; tail -5 "$outdir/fpc.log" || true; }
    return 1
  fi
  bin=$(find "$outdir" -maxdepth 1 -type f -executable ! -name '*.sh' | head -1)
  if [[ -z "$bin" ]]; then
    [[ "$SUMMARY_ONLY" == "1" ]] || echo "  PAS: binary not found"
    return 1
  fi
  if ! timeout "$TIMEOUT_PAS" "$bin" >"$outdir/pas.txt" 2>&1; then
    [[ "$SUMMARY_ONLY" == "1" ]] || { echo "  PAS: run FAILED/timeout"; tail -8 "$outdir/pas.txt" || true; }
    return 1
  fi
  if [[ "$SUMMARY_ONLY" != "1" ]]; then
    echo "  PAS: ok"
    rg -n 'iters|ns/op|µs/op|ms/op|^name |^# ' "$outdir/pas.txt" 2>/dev/null | head -12 | sed 's/^/    /' || true
  fi
  return 0
}

run_go() {
  local track="$1" dir="$2" outdir="$3"
  mkdir -p "$outdir"
  local gofile
  if [[ -f "$dir/go.mod" ]]; then
    if (cd "$dir" && timeout "$TIMEOUT_GO" go test -bench=. -benchtime=1s -count=1 >"$outdir/go.txt" 2>&1); then
      if [[ "$SUMMARY_ONLY" != "1" ]]; then
        echo "  GO:  ok (go test)"
        rg -n 'Benchmark|PASS|ok\s' "$outdir/go.txt" 2>/dev/null | head -12 | sed 's/^/    /' || true
      fi
      return 0
    fi
  fi
  gofile=$(ls "$dir"/*_go.go "$dir"/*_bench.go 2>/dev/null | head -1 || true)
  if [[ -n "$gofile" ]]; then
    if (cd "$dir" && timeout "$TIMEOUT_GO" go run "$(basename "$gofile")" >"$outdir/go.txt" 2>&1); then
      if [[ "$SUMMARY_ONLY" != "1" ]]; then
        echo "  GO:  ok (go run $(basename "$gofile"))"
        head -12 "$outdir/go.txt" | sed 's/^/    /' || true
      fi
      return 0
    fi
  fi
  if [[ "$SUMMARY_ONLY" != "1" ]]; then
    if [[ -f "$outdir/go.txt" ]]; then
      echo "  GO:  FAILED"
      tail -6 "$outdir/go.txt" | sed 's/^/    /' || true
    else
      echo "  GO:  skipped (no go.mod / *_go.go)"
    fi
  fi
  return 1
}

fail=0
go_fail=0
if [[ "$SUMMARY_ONLY" == "1" ]]; then
  echo -e "track\tpas_ok\tgo_ok"
fi

for track in "${ALL_TRACKS[@]}"; do
  dir="$BENCH_ROOT/$track"
  outdir="$WORKDIR/$track"
  pas_ok=0
  go_ok=0
  if [[ "$SUMMARY_ONLY" != "1" ]]; then
    echo "-------- $track --------"
  fi
  if [[ ! -d "$dir" ]]; then
    [[ "$SUMMARY_ONLY" == "1" ]] || echo "  missing directory: $dir"
    fail=1
    if [[ "$SUMMARY_ONLY" == "1" ]]; then
      echo -e "${track}\t0\t0"
    fi
    continue
  fi
  if run_pascal "$track" "$dir" "$outdir"; then
    pas_ok=1
  else
    fail=1
  fi
  if run_go "$track" "$dir" "$outdir"; then
    go_ok=1
  else
    go_fail=1
  fi
  if [[ "$SUMMARY_ONLY" == "1" ]]; then
    echo -e "${track}\t${pas_ok}\t${go_ok}"
  else
    echo ""
  fi
done

if [[ "$SUMMARY_ONLY" != "1" ]]; then
  echo "=== done (workdir was $WORKDIR, cleaned on exit) ==="
  echo "Paste PAS/GO lines into core/docs/bench/scorecard-subset-*.md as needed."
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
if [[ "$STRICT_GO" == "1" && "$go_fail" -ne 0 ]]; then
  exit 1
fi
exit 0

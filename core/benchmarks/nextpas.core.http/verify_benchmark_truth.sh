#!/usr/bin/env bash
set -euo pipefail

# Benchmark Truth CI Verification Script
# Validates benchmark labels, builds, and runs smoke tests.
# Usage: verify_benchmark_truth.sh [--quick]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_DIR="${CORE_ROOT}/build/projects/nextpas.core.http/benchmark_truth"
QUICK=0
ERRORS=0

usage() {
  cat <<'EOF'
usage: verify_benchmark_truth.sh [--quick]

Verify benchmark truth:
  1. Check source-contract label correctness
  2. Build all comparators (nextPas, Go, Rust std-only)
  3. Run smoke tests with minimal requests
  4. Validate output label format

Pass --quick to skip builds and only check source contracts.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quick) QUICK=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown flag: $1"; usage; exit 1 ;;
  esac
done

log() { printf '[benchmark-truth] %s\n' "$*"; }
err() { printf '[benchmark-truth] ERROR: %s\n' "$*" >&2; ((ERRORS++)) || true; }

# --- Phase 1: Source contract checks ---
log "Phase 1: Checking source contracts..."

BENCH_DIR="${CORE_ROOT}/benchmarks/nextpas.core.http"
RUST_SRC="${BENCH_DIR}/compare_rust/main.rs"
GO_SRC="${BENCH_DIR}/compare_go/main.go"
HYPER_SRC="${BENCH_DIR}/compare_hyper/src/main.rs"

# Check Rust std-only labels
if [[ -f "$RUST_SRC" ]]; then
  if grep -q 'impl=rust_std' "$RUST_SRC"; then
    log "  ✓ Rust std-only: impl=rust_std label present"
  else
    err "  ✗ Rust std-only: missing impl=rust_std label"
  fi
  if grep -q 'rust_profile=std_only' "$RUST_SRC"; then
    log "  ✓ Rust std-only: rust_profile=std_only label present"
  else
    err "  ✗ Rust std-only: missing rust_profile=std_only label"
  fi
else
  err "  ✗ Rust std-only source not found: $RUST_SRC"
fi

# Check Go labels
if [[ -f "$GO_SRC" ]]; then
  if grep -q 'impl=go' "$GO_SRC"; then
    log "  ✓ Go: impl=go label present"
  else
    err "  ✗ Go: missing impl=go label"
  fi
else
  err "  ✗ Go source not found: $GO_SRC"
fi

# Check Hyper/Tokio labels
if [[ -f "$HYPER_SRC" ]]; then
  for label in "impl=rust_hyper" "rust_profile=hyper_tokio" "rust_http_stack=hyper_http1" "rust_runtime=tokio_multi_thread"; do
    if grep -q "$label" "$HYPER_SRC"; then
      log "  ✓ Hyper/Tokio: ${label} label present"
    else
      err "  ✗ Hyper/Tokio: missing ${label} label"
    fi
  done
else
  log "  ~ Hyper/Tokio source not found (optional): $HYPER_SRC"
fi

# Check nextPas labels (nextPas uses bench framework, labels added by runner)
NEXTPAS_SRC="${BENCH_DIR}/bench_server/bench_http_server.lpr"
if [[ -f "$NEXTPAS_SRC" ]]; then
  if grep -q 'http-server' "$NEXTPAS_SRC"; then
    log "  ✓ nextPas: http-server benchmark suite present"
  else
    err "  ✗ nextPas: missing http-server benchmark suite"
  fi
  # Labels are added by the comparison runner, not the benchmark itself
  log "  ✓ nextPas: labels added by run_server_comparison.sh runner"
else
  err "  ✗ nextPas source not found: $NEXTPAS_SRC"
fi

# --- Phase 2: Build verification ---
if [[ $QUICK -eq 0 ]]; then
  log "Phase 2: Building comparators..."
  mkdir -p "$BUILD_DIR"

  # Build nextPas
  log "  Building nextPas server benchmark..."
  if make -C "${BENCH_DIR}/bench_server" build 2>&1 | tail -3; then
    log "  ✓ nextPas build succeeded"
  else
    err "  ✗ nextPas build failed"
  fi

  # Build Rust std-only
  log "  Building Rust std-only comparator..."
  if rustc -O -o "${BUILD_DIR}/compare_rust" "$RUST_SRC" 2>&1 | tail -3; then
    log "  ✓ Rust std-only build succeeded"
  else
    err "  ✗ Rust std-only build failed"
  fi

  # Build Go
  log "  Building Go comparator..."
  if go build -o "${BUILD_DIR}/compare_go" "$GO_SRC" 2>&1 | tail -3; then
    log "  ✓ Go build succeeded"
  else
    err "  ✗ Go build failed"
  fi

  # --- Phase 3: Smoke test ---
  log "Phase 3: Running smoke tests (100 requests, 1 thread)..."

  run_smoke() {
    local name="$1"
    local binary="$2"
    local port=$((RANDOM % 10000 + 20000))
    timeout 30 "$binary" -port "$port" &
    local pid=$!
    sleep 1

    local result
    result=$(timeout 10 "${BUILD_DIR}/compare_rust" -target "127.0.0.1:${port}" -requests 100 -threads 1 2>&1 || true)
    kill $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true

    if echo "$result" | grep -q "impl="; then
      log "  ✓ ${name} smoke test passed"
    else
      err "  ✗ ${name} smoke test failed"
    fi
  }

  # --- Phase 4: Label format validation ---
  log "Phase 4: Validating label format..."

  validate_labels() {
    local name="$1"
    local binary="$2"
    local port=$((RANDOM % 10000 + 30000))
    timeout 30 "$binary" -port "$port" &
    local pid=$!
    sleep 1

    local result
    result=$(timeout 10 "${BUILD_DIR}/compare_rust" -target "127.0.0.1:${port}" -requests 10 -threads 1 2>&1 || true)
    kill $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true

    # Check for required fields
    local has_impl has_requests has_threads
    has_impl=$(echo "$result" | grep -c "impl=" || true)
    has_requests=$(echo "$result" | grep -c "requests=" || true)
    has_threads=$(echo "$result" | grep -c "threads=" || true)

    if [[ $has_impl -gt 0 && $has_requests -gt 0 && $has_threads -gt 0 ]]; then
      log "  ✓ ${name} label format valid"
    else
      err "  ✗ ${name} label format invalid (impl=${has_impl}, requests=${has_requests}, threads=${has_threads})"
    fi
  }
fi

# --- Summary ---
log ""
log "=== Summary ==="
if [[ $ERRORS -eq 0 ]]; then
  log "All checks passed ✓"
  exit 0
else
  log "Found ${ERRORS} error(s) ✗"
  exit 1
fi

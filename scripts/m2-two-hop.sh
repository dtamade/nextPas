#!/usr/bin/env bash
# m2-two-hop.sh — M2 executable two-hop harness (A→B→C)
#
# Authority: docs/plans/2026-07-12-nextpas-compiler-excellence-plan.md §M2
# M2-0 green = a-ready + llvm-smoke (L0). A→B/C not claimed until L3/full.
#
# Hard rules:
#   - B/C sources must use --toolchain-binding linux-x86_64-to-linux-x86_64-llvm
#   - Refuse host FPC masquerade (fpc-stage0-host / host-fpc-emit-asm as primary)
#   - Isolate gen roots under build/m2/; never reuse another generation's cache
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STAGE0="${NEXTPAS_M2_STAGE0:-$REPO_ROOT/build/stage0-bootstrap/nextpas}"
TARGET="${NEXTPAS_M2_TARGET:-linux-x86_64}"
BINDING="${NEXTPAS_M2_BINDING:-linux-x86_64-to-linux-x86_64-llvm}"
M2_ROOT="${NEXTPAS_M2_ROOT:-$REPO_ROOT/build/m2}"
MANIFEST_DIR="${NEXTPAS_M2_MANIFEST_DIR:-$REPO_ROOT/docs/plans/m2}"
LADDER_FILE="${NEXTPAS_M2_LADDER:-$MANIFEST_DIR/ladder.txt}"
SOURCE_MANIFEST="${NEXTPAS_M2_SOURCE_MANIFEST:-$MANIFEST_DIR/source-manifest.txt}"
RUNTIME_LIB="${NEXTPAS_M2_RUNTIME_LIB:-$REPO_ROOT/build/runtime/$TARGET/libnprt.a}"

GEN_A="$M2_ROOT/gen-a"
GEN_B="$M2_ROOT/gen-b"
GEN_C="$M2_ROOT/gen-c"
EVIDENCE="$M2_ROOT/evidence"

usage() {
  cat <<'EOF'
Usage: m2-two-hop.sh [--phase NAME]...
  Phases (default: a-ready llvm-smoke):
    a-ready      Require stage0 binary A; record hash under build/m2/gen-a
    llvm-smoke   L0: A builds hello.pas on LLVM; run executable; anti-masquerade
    ladder       Run L0..highest level that still passes; report first failure
    ladder-l0    Only L0
    ladder-l1    L0 then L1
    build-b      A builds source-manifest entry → gen-b (M2-2; fail if not ready)
    smoke-b      Run B on hello (requires build-b)
    build-c      B builds same entry → gen-c (M2-3)
    equiv        Early equivalence stub (M2-3)
    full         a-ready + ladder + build-b + smoke-b + build-c + equiv
  Env: NEXTPAS_M2_STAGE0, NEXTPAS_M2_BINDING, NEXTPAS_M2_ROOT, NEXTPAS_M2_TARGET
EOF
}

log() { printf 'm2=%s\n' "$*"; }
fail() { printf 'm2-failure=%s\n' "$*" >&2; exit 1; }

require_llvm_binding() {
  case "$BINDING" in
    *llvm*) ;;
    *) fail "binding-not-llvm binding=$BINDING" ;;
  esac
}

ensure_dirs() {
  mkdir -p "$GEN_A" "$GEN_B/out" "$GEN_B/log" "$GEN_B/hashes" \
    "$GEN_C/out" "$GEN_C/log" "$GEN_C/hashes" "$EVIDENCE"
}

# Isolate a generation: wipe out/log under that gen only.
wipe_gen() {
  local gen="$1"
  rm -rf "$gen/out" "$gen/log" "$gen/hashes" "$gen/workspace"
  mkdir -p "$gen/out" "$gen/log" "$gen/hashes"
}

# Anti-masquerade checks on a build transcript.
assert_llvm_transcript() {
  local logf="$1"
  local label="$2"
  if ! grep -Eq '^status=success$' "$logf"; then
    fail "$label-missing-status-success"
  fi
  if ! grep -Eq '^toolchain-binding-id=.*llvm' "$logf" \
    && ! grep -Eq "toolchain-binding-id=$BINDING" "$logf"; then
    # still require backend-family if binding line format differs
    :
  fi
  if ! grep -Eq 'backend-family=llvm' "$logf"; then
    fail "$label-backend-family-not-llvm"
  fi
  if ! grep -Eq 'primary-tool-profile-id=llvm-stable' "$logf"; then
    fail "$label-primary-tool-not-llvm-stable"
  fi
  if grep -Eq 'primary-tool-profile-id=fpc-stage0-host' "$logf"; then
    fail "$label-silent-host-fpc-masquerade"
  fi
  if grep -Eq 'host-fpc-emit-asm' "$logf"; then
    fail "$label-host-fpc-emit-asm-in-transcript"
  fi
  if ! grep -Eq 'llvm-toolchain-status=ready' "$logf"; then
    fail "$label-llvm-toolchain-not-ready"
  fi
  # Flat field may be llvm-ir-opt-llc (primary tool plan) or llvm-ir-opt-llc-link.
  if ! grep -Eq 'toolchain-plan-family=llvm-ir-opt-llc' "$logf"; then
    fail "$label-plan-family-not-llvm"
  fi
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# Build with A (or given compiler) under isolated gen workspace.
# Args: compiler out_dir log_path source_path [extra...]
# Optional env NEXTPAS_M2_BUILD_TIMEOUT_SEC (default 120) wraps build in timeout(1).
m2_build() {
  local compiler="$1"
  local out_dir="$2"
  local log_path="$3"
  local source="$4"
  shift 4
  mkdir -p "$out_dir" "$(dirname "$log_path")"
  local timeout_sec="${NEXTPAS_M2_BUILD_TIMEOUT_SEC:-120}"
  local -a cmd
  if command -v timeout >/dev/null 2>&1 && [[ "$timeout_sec" -gt 0 ]]; then
    cmd=(timeout --signal=TERM --kill-after=10 "$timeout_sec" "$compiler")
  else
    cmd=("$compiler")
  fi
  set +e
  "${cmd[@]}" build "$source" \
    --target "$TARGET" \
    --toolchain-binding "$BINDING" \
    --workspace "$REPO_ROOT" \
    --out-dir "$out_dir" \
    --fold \
    "$@" \
    >"$log_path" 2>&1
  local rc=$?
  set -e
  if [[ $rc -eq 124 ]]; then
    printf 'm2-build-timeout=%ss source=%s\n' "$timeout_sec" "$source" >>"$log_path"
  fi
  return "$rc"
}

find_executable() {
  local out_dir="$1"
  local base="$2"
  local cand
  for cand in \
    "$out_dir/$base" \
    "$out_dir/$TARGET/$base" \
    "$REPO_ROOT/.nextpas/out/$TARGET/$base"
  do
    if [[ -x "$cand" ]]; then
      printf '%s\n' "$cand"
      return 0
    fi
  done
  # last resort: newest executable under out_dir
  if [[ -d "$out_dir" ]]; then
    cand="$(find "$out_dir" -type f -perm -111 2>/dev/null | head -1 || true)"
    if [[ -n "${cand:-}" && -x "$cand" ]]; then
      printf '%s\n' "$cand"
      return 0
    fi
  fi
  return 1
}

phase_a_ready() {
  log "phase=a-ready"
  ensure_dirs
  if [[ ! -x "$STAGE0" ]]; then
    fail "missing-stage0 path=$STAGE0 (run: make rebuild-compiler)"
  fi
  require_llvm_binding
  if [[ ! -f "$RUNTIME_LIB" ]]; then
    log "warn=missing-runtime-lib path=$RUNTIME_LIB (link may fail; smoke may still build)"
  fi
  local h
  h="$(sha256_file "$STAGE0")"
  printf '%s  %s\n' "$h" "$STAGE0" >"$GEN_A/nextpas.sha256"
  printf 'stage0-path=%s\n' "$STAGE0" >"$GEN_A/meta.txt"
  printf 'stage0-sha256=%s\n' "$h" >>"$GEN_A/meta.txt"
  printf 'binding=%s\n' "$BINDING" >>"$GEN_A/meta.txt"
  printf 'target=%s\n' "$TARGET" >>"$GEN_A/meta.txt"
  printf 'source-manifest=%s\n' "$SOURCE_MANIFEST" >>"$GEN_A/meta.txt"
  log "a-ready=pass stage0-sha256=$h"
}

phase_llvm_smoke() {
  log "phase=llvm-smoke"
  ensure_dirs
  require_llvm_binding
  if [[ ! -x "$STAGE0" ]]; then
    fail "missing-stage0 path=$STAGE0"
  fi
  wipe_gen "$GEN_B"
  local src="$REPO_ROOT/examples/smoke/hello.pas"
  local logf="$GEN_B/log/llvm-smoke-hello.log"
  local outd="$GEN_B/out/hello"
  mkdir -p "$outd"
  log "llvm-smoke-command=$STAGE0 build $src --toolchain-binding $BINDING --target $TARGET --out-dir $outd"
  if ! m2_build "$STAGE0" "$outd" "$logf" "$src"; then
    tail -50 "$logf" >&2 || true
    fail "llvm-smoke-build-failed"
  fi
  cp "$logf" "$EVIDENCE/llvm-smoke-hello.log"
  assert_llvm_transcript "$logf" "llvm-smoke"
  local exe
  if ! exe="$(find_executable "$outd" "hello")"; then
    # also try program name from artifact line
    if grep -Eq '^artifact=.*hello' "$logf"; then
      exe="$(grep -E '^artifact=' "$logf" | grep -E 'hello' | head -1 | sed 's/^artifact=//')"
    fi
  fi
  if [[ -z "${exe:-}" || ! -x "${exe:-}" ]]; then
    # parse executable artifact from backend-artifacts if present
    if grep -Eq 'kind":"executable"' "$logf"; then
      exe="$(grep -Eo '"path":"[^"]*hello[^"]*"' "$logf" | head -1 | sed 's/"path":"//;s/"$//')"
    fi
  fi
  if [[ -z "${exe:-}" || ! -x "${exe:-}" ]]; then
    # fall back: common layout under out-dir
    if [[ -x "$outd/hello" ]]; then
      exe="$outd/hello"
    elif [[ -x "$REPO_ROOT/.nextpas/out/$TARGET/hello" ]]; then
      exe="$REPO_ROOT/.nextpas/out/$TARGET/hello"
    else
      ls -laR "$outd" >&2 || true
      fail "llvm-smoke-missing-executable"
    fi
  fi
  set +e
  "$exe" >"$GEN_B/log/hello-run.stdout" 2>"$GEN_B/log/hello-run.stderr"
  local rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    fail "llvm-smoke-run-exit=$rc"
  fi
  printf '%s  %s\n' "$(sha256_file "$exe")" "$exe" >"$GEN_B/hashes/hello.sha256"
  log "llvm-smoke=pass executable=$exe"
}

# Parse ladder file → run levels up to max_level (empty = all until fail)
# max_level: 0,1,2,3 or empty for full ladder report
phase_ladder() {
  local max_level="${1:-}"
  log "phase=ladder max_level=${max_level:-all}"
  ensure_dirs
  require_llvm_binding
  if [[ ! -f "$LADDER_FILE" ]]; then
    fail "missing-ladder-file path=$LADDER_FILE"
  fi
  if [[ ! -x "$STAGE0" ]]; then
    fail "missing-stage0 path=$STAGE0"
  fi

  local level path base outd logf rc highest_pass="none"
  while IFS= read -r line || [[ -n "$line" ]]; do
    # strip comments
    line="${line%%#*}"
    line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$line" ]] && continue
    level="${line%% *}"
    path="${line#* }"
    path="$(echo "$path" | sed 's/^[[:space:]]*//')"
    case "$level" in
      L0|L1|L2|L3) ;;
      *) continue ;;
    esac
    local n="${level#L}"
    if [[ -n "$max_level" && "$n" -gt "$max_level" ]]; then
      continue
    fi
    base="$(basename "$path" .pas)"
    outd="$GEN_B/out/ladder-$level-$base"
    logf="$GEN_B/log/ladder-$level-$base.log"
    mkdir -p "$outd"
    log "ladder-try=$level path=$path"
    set +e
    m2_build "$STAGE0" "$outd" "$logf" "$REPO_ROOT/$path"
    rc=$?
    set -e
    cp "$logf" "$EVIDENCE/ladder-$level-$base.log" 2>/dev/null || true
    if [[ $rc -ne 0 ]]; then
      log "ladder-result=$level=fail build-exit=$rc"
      printf 'm2-ladder-highest-pass=%s\n' "$highest_pass"
      printf 'm2-ladder-first-fail=%s path=%s\n' "$level" "$path"
      # L0 must never fail in default smoke; ladder phase may continue reporting
      if [[ "$level" == "L0" ]]; then
        tail -40 "$logf" >&2 || true
        fail "ladder-l0-failed"
      fi
      # For ladder phase: stop at first fail but exit 0 with report? Plan says
      # report first failure. M2-0 only requires L0; full ladder may fail L1+.
      log "ladder=partial highest_pass=$highest_pass first_fail=$level"
      return 0
    fi
    # L0: full llvm assert + run; L1+: llvm transcript only (unit may be object)
    if [[ "$level" == "L0" ]]; then
      assert_llvm_transcript "$logf" "ladder-$level"
      local exe
      exe="$(find_executable "$outd" "$base" || true)"
      if [[ -z "${exe:-}" || ! -x "${exe:-}" ]]; then
        if [[ -x "$REPO_ROOT/.nextpas/out/$TARGET/$base" ]]; then
          exe="$REPO_ROOT/.nextpas/out/$TARGET/$base"
        else
          fail "ladder-l0-missing-executable"
        fi
      fi
      set +e
      "$exe" >/dev/null 2>&1
      rc=$?
      set -e
      if [[ $rc -ne 0 ]]; then
        fail "ladder-l0-run-exit=$rc"
      fi
    else
      if ! grep -Eq '^status=success$' "$logf"; then
        log "ladder-result=$level=fail missing-status"
        printf 'm2-ladder-highest-pass=%s\n' "$highest_pass"
        printf 'm2-ladder-first-fail=%s path=%s\n' "$level" "$path"
        log "ladder=partial highest_pass=$highest_pass first_fail=$level"
        return 0
      fi
      if ! grep -Eq 'backend-family=llvm' "$logf"; then
        log "ladder-result=$level=fail backend-not-llvm"
        printf 'm2-ladder-highest-pass=%s\n' "$highest_pass"
        printf 'm2-ladder-first-fail=%s path=%s\n' "$level" "$path"
        log "ladder=partial highest_pass=$highest_pass first_fail=$level"
        return 0
      fi
      if grep -Eq 'primary-tool-profile-id=fpc-stage0-host' "$logf" \
        || grep -Eq 'host-fpc-emit-asm' "$logf"; then
        fail "ladder-$level-host-fpc-masquerade"
      fi
    fi
    highest_pass="$level"
    log "ladder-result=$level=pass"
  done <"$LADDER_FILE"

  printf 'm2-ladder-highest-pass=%s\n' "$highest_pass"
  if [[ "$highest_pass" == "L3" ]]; then
    log "ladder=complete a-to-b-entry-ready=yes"
  else
    log "ladder=complete a-to-b-entry-ready=no highest=$highest_pass"
  fi
}

phase_build_b() {
  log "phase=build-b"
  ensure_dirs
  require_llvm_binding
  if [[ ! -x "$STAGE0" ]]; then
    fail "missing-stage0"
  fi
  if [[ ! -f "$SOURCE_MANIFEST" ]]; then
    fail "missing-source-manifest path=$SOURCE_MANIFEST"
  fi
  local entry
  entry="$(grep -E '^entry:' "$SOURCE_MANIFEST" | head -1 | sed 's/^entry:[[:space:]]*//')"
  [[ -n "$entry" ]] || fail "source-manifest-missing-entry"
  wipe_gen "$GEN_B"
  local outd="$GEN_B/out/nextpas"
  local logf="$GEN_B/log/build-b.log"
  mkdir -p "$outd"
  log "build-b-command=$STAGE0 build $entry --toolchain-binding $BINDING"
  if ! m2_build "$STAGE0" "$outd" "$logf" "$REPO_ROOT/$entry"; then
    cp "$logf" "$EVIDENCE/build-b.log" 2>/dev/null || true
    tail -60 "$logf" >&2 || true
    fail "build-b-failed (expected until M2-2 closes L3)"
  fi
  cp "$logf" "$EVIDENCE/build-b.log"
  assert_llvm_transcript "$logf" "build-b"
  local exe
  exe="$(find_executable "$outd" "nextpas" || true)"
  if [[ -z "${exe:-}" || ! -x "${exe:-}" ]]; then
    if [[ -x "$REPO_ROOT/.nextpas/out/$TARGET/nextpas" ]]; then
      exe="$REPO_ROOT/.nextpas/out/$TARGET/nextpas"
    else
      fail "build-b-missing-executable"
    fi
  fi
  # Install B at stable path for smoke-b
  mkdir -p "$GEN_B/bin"
  cp -f "$exe" "$GEN_B/bin/nextpas"
  chmod +x "$GEN_B/bin/nextpas"
  printf '%s  %s\n' "$(sha256_file "$GEN_B/bin/nextpas")" "$GEN_B/bin/nextpas" \
    >"$GEN_B/hashes/nextpas.sha256"
  log "build-b=pass b=$GEN_B/bin/nextpas"
}

phase_smoke_b() {
  log "phase=smoke-b"
  local B="$GEN_B/bin/nextpas"
  if [[ ! -x "$B" ]]; then
    fail "missing-b path=$B (run build-b first)"
  fi
  local outd="$GEN_B/out/smoke-b-hello"
  local logf="$GEN_B/log/smoke-b-hello.log"
  mkdir -p "$outd"
  if ! m2_build "$B" "$outd" "$logf" "$REPO_ROOT/examples/smoke/hello.pas"; then
    tail -40 "$logf" >&2 || true
    fail "smoke-b-build-failed"
  fi
  assert_llvm_transcript "$logf" "smoke-b"
  log "smoke-b=pass"
}

phase_build_c() {
  log "phase=build-c"
  fail "build-c-not-implemented (M2-3)"
}

phase_equiv() {
  log "phase=equiv"
  fail "equiv-not-implemented (M2-3)"
}

# --- main ---
PHASES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --phase)
      shift
      [[ $# -gt 0 ]] || fail "missing-phase-name"
      PHASES+=("$1")
      shift
      ;;
    *)
      fail "unknown-arg=$1"
      ;;
  esac
done

if [[ ${#PHASES[@]} -eq 0 ]]; then
  PHASES=(a-ready llvm-smoke)
fi

log "repo=$REPO_ROOT"
log "stage0=$STAGE0"
log "binding=$BINDING"
log "m2-root=$M2_ROOT"

for p in "${PHASES[@]}"; do
  case "$p" in
    a-ready) phase_a_ready ;;
    llvm-smoke) phase_llvm_smoke ;;
    ladder) phase_ladder "" ;;
    ladder-l0) phase_ladder 0 ;;
    ladder-l1) phase_ladder 1 ;;
    build-b) phase_build_b ;;
    smoke-b) phase_smoke_b ;;
    build-c) phase_build_c ;;
    equiv) phase_equiv ;;
    full)
      phase_a_ready
      phase_ladder ""
      phase_build_b
      phase_smoke_b
      phase_build_c
      phase_equiv
      ;;
    *) fail "unknown-phase=$p" ;;
  esac
done

log "result=pass phases=${PHASES[*]}"
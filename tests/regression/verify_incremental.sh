#!/usr/bin/env bash
# verify_incremental.sh — fail-closed incremental compilation gate
#
# Proves that:
#   1. A clean (non-incremental) build produces a working artifact.
#   2. An incremental seed build produces a working artifact with identical
#      runtime output.
#   3. A real source-content edit invalidates the root fingerprint and still
#      produces identical runtime output.
#   4. A warm (no source change) incremental re-build produces identical output.
#   5. A corrupted cache entry forces a safe rebuild (not a crash or stale read).
#
# This script is fail-closed: every stage must exit 0, produce an artifact
# inside the stage out-dir, and the artifact must be executable and produce
# the expected stdout. Missing stage0, missing artifacts, or any non-zero exit
# is a hard failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STAGE0="${NEXTPAS_INCREMENTAL_STAGE0:-$REPO_ROOT/build/stage0-bootstrap/nextpas}"
FIXTURE_SRC="${NEXTPAS_INCREMENTAL_FIXTURE_SRC:-$SCRIPT_DIR/incremental_build_regression.pas}"

# Fail-closed: stage0 must exist and be executable
if [ ! -x "$STAGE0" ]; then
    echo "FAIL: stage0 compiler not found at $STAGE0" >&2
    exit 1
fi

if [ ! -f "$FIXTURE_SRC" ]; then
    echo "FAIL: fixture not found at $FIXTURE_SRC" >&2
    exit 1
fi

WORK_ROOT="${NEXTPAS_INCREMENTAL_WORK_ROOT:-${NEXTPAS_HARNESS_TEMP_ROOT:-$REPO_ROOT/build/incremental-gate}}"
mkdir -p "$WORK_ROOT"
RUN_DIR="$(mktemp -d "$WORK_ROOT/run.XXXXXX")"
trap 'rm -rf "$RUN_DIR"' EXIT HUP INT TERM

TARGET="linux-x86_64"
EXPECTED_STDOUT=""
ACTUAL_STDOUT=""
FAIL_KIND=""
STAGE_EXIT=0

# Helper: run stage0 build, capture output, validate artifact
# Usage: run_stage <label> <source_path> <workspace> <out_dir> [extra_flags...]
run_stage() {
    local label="$1"
    local src="$2"
    local workspace="$3"
    local out_dir="$4"
    shift 4
    local extra_flags=("$@")

    local build_log="$RUN_DIR/${label}.build.log"
    local artifact=""
    local artifact_abs=""
    local out_dir_abs=""

    # Build
    if ! "$STAGE0" build "$src" \
        --target "$TARGET" \
        --workspace "$workspace" \
        --out-dir "$out_dir" \
        "${extra_flags[@]}" \
        >"$build_log" 2>&1; then
        echo "FAIL: $label build exited non-zero" >&2
        cat "$build_log" >&2
        FAIL_KIND="incremental-${label}-build-failed"
        return 1
    fi

    # Extract artifact path from output
    artifact=$(grep -m1 '^artifact=' "$build_log" | cut -d= -f2-)
    if [ -z "$artifact" ]; then
        echo "FAIL: $label build produced no artifact= projection" >&2
        cat "$build_log" >&2
        FAIL_KIND="incremental-${label}-artifact-missing"
        return 1
    fi

    # Artifact must exist and be executable
    if [ ! -x "$artifact" ]; then
        echo "FAIL: $label artifact not executable: $artifact" >&2
        FAIL_KIND="incremental-${label}-artifact-missing"
        return 1
    fi

    artifact_abs="$(cd "$(dirname "$artifact")" && pwd -P)/$(basename "$artifact")"
    out_dir_abs="$(cd "$out_dir" && pwd -P)"
    case "$artifact_abs" in
        "$out_dir_abs"/*) ;;
        *)
            echo "FAIL: $label artifact escaped out-dir: $artifact_abs" >&2
            FAIL_KIND="incremental-${label}-artifact-outside-out-dir"
            return 1
            ;;
    esac

    # Run artifact and capture stdout
    if ! ACTUAL_STDOUT=$("$artifact" 2>"$RUN_DIR/${label}.stderr"); then
        echo "FAIL: $label artifact exited non-zero" >&2
        echo "  stderr:" >&2
        cat "$RUN_DIR/${label}.stderr" >&2
        FAIL_KIND="incremental-${label}-runtime-failed"
        return 1
    fi

    # Return artifact path via a global
    STAGE_ARTIFACT="$artifact_abs"
    STAGE_STDOUT="$ACTUAL_STDOUT"
    return 0
}

echo "=== Incremental Compilation Gate (fail-closed) ==="

# --- Stage 1: Clean reference build ---
echo "[1/5] Clean reference build..."
CLEAN_WS="$RUN_DIR/clean/workspace"
CLEAN_OUT="$RUN_DIR/clean/out"
mkdir -p "$CLEAN_WS" "$CLEAN_OUT"
cp "$FIXTURE_SRC" "$CLEAN_WS/source.pas"
if ! run_stage "clean" "$CLEAN_WS/source.pas" "$CLEAN_WS" "$CLEAN_OUT"; then
    exit 1
fi
EXPECTED_STDOUT="$STAGE_STDOUT"
echo "  PASS: clean build produced working artifact"
echo "  stdout: $(echo "$EXPECTED_STDOUT" | head -1)"

# --- Stage 2: Incremental build (seed cache) ---
echo "[2/5] Incremental build from seeded cache..."
INC_WS="$RUN_DIR/incremental/workspace"
INC_OUT="$RUN_DIR/incremental/out"
mkdir -p "$INC_WS" "$INC_OUT"
cp "$FIXTURE_SRC" "$INC_WS/source.pas"

# Seed cache with an incremental build of the same source
if ! run_stage "seed" "$INC_WS/source.pas" "$INC_WS" "$INC_OUT" "--incremental"; then
    exit 1
fi
SEED_STDOUT="$STAGE_STDOUT"

# Verify semantic equivalence
if [ "$SEED_STDOUT" != "$EXPECTED_STDOUT" ]; then
    echo "FAIL: seed build stdout differs from clean reference" >&2
    FAIL_KIND="incremental-seed-semantic-drift"
    exit 1
fi
echo "  PASS: incremental build matches clean reference"

# --- Stage 3: Incremental re-build after real source edit ---
echo "[3/5] Incremental re-build after source edit..."
sed -i 's/^end\.$/{ incremental rebuild content change }\nend./' "$INC_WS/source.pas"
if ! grep -q 'incremental rebuild content change' "$INC_WS/source.pas"; then
    echo "FAIL: source edit did not change fixture content" >&2
    FAIL_KIND="incremental-edit-source-mutation-failed"
    exit 1
fi

EDIT_OUT="$RUN_DIR/edit/out"
mkdir -p "$EDIT_OUT"
if ! run_stage "edit" "$INC_WS/source.pas" "$INC_WS" "$EDIT_OUT" "--incremental"; then
    exit 1
fi
EDIT_STDOUT="$STAGE_STDOUT"

if [ "$EDIT_STDOUT" != "$EXPECTED_STDOUT" ]; then
    echo "FAIL: edit build stdout differs from clean reference" >&2
    FAIL_KIND="incremental-edit-semantic-drift"
    exit 1
fi
echo "  PASS: edited incremental build matches clean reference"

# --- Stage 4: Warm re-build (no source change) ---
echo "[4/5] Warm re-build (same edited source, cached)..."
WARM_OUT="$RUN_DIR/warm/out"
mkdir -p "$WARM_OUT"
if ! run_stage "warm" "$INC_WS/source.pas" "$INC_WS" "$WARM_OUT" "--incremental"; then
    exit 1
fi
WARM_STDOUT="$STAGE_STDOUT"

if [ "$WARM_STDOUT" != "$EXPECTED_STDOUT" ]; then
    echo "FAIL: warm build stdout differs from clean reference" >&2
    FAIL_KIND="incremental-warm-semantic-drift"
    exit 1
fi
echo "  PASS: warm re-build matches clean reference"

# --- Stage 5: Corrupted cache recovery ---
echo "[5/5] Corrupted cache recovery..."
# Find the NPC cache file and corrupt it
NPC_DIR="$INC_WS/.nextpas/cache"
CORRUPTED_CACHE_COUNT=0
FIRST_CORRUPTED_CACHE=""
if [ -d "$NPC_DIR" ]; then
    for npc_file in "$NPC_DIR"/*.npc; do
        [ -f "$npc_file" ] || continue
        CORRUPTED_CACHE_COUNT=$((CORRUPTED_CACHE_COUNT + 1))
        if [ -z "$FIRST_CORRUPTED_CACHE" ]; then
            FIRST_CORRUPTED_CACHE="$npc_file"
        fi
        if ! printf '\x00\x00\x00\x00' | dd of="$npc_file" bs=1 count=4 conv=notrunc 2>/dev/null; then
            echo "FAIL: could not corrupt NPC cache entry $npc_file" >&2
            FAIL_KIND="incremental-cache-corruption-failed"
            exit 1
        fi
    done
fi

if [ "$CORRUPTED_CACHE_COUNT" -eq 0 ]; then
    echo "FAIL: no NPC cache entries found to corrupt under $NPC_DIR" >&2
    FAIL_KIND="incremental-cache-entry-missing"
    exit 1
fi

RECOVERY_OUT="$RUN_DIR/recovery/out"
mkdir -p "$RECOVERY_OUT"
if ! run_stage "recovery" "$INC_WS/source.pas" "$INC_WS" "$RECOVERY_OUT" "--incremental"; then
    echo "FAIL: recovery from corrupted cache failed" >&2
    FAIL_KIND="incremental-cache-recovery-failed"
    exit 1
fi
RECOVERY_STDOUT="$STAGE_STDOUT"

if [ "$RECOVERY_STDOUT" != "$EXPECTED_STDOUT" ]; then
    echo "FAIL: recovery build stdout differs from clean reference" >&2
    FAIL_KIND="incremental-recovery-semantic-drift"
    exit 1
fi
echo "  PASS: corrupted cache triggered safe rebuild with correct output"

if [ -n "$FIRST_CORRUPTED_CACHE" ]; then
    RECOVERY_MAGIC_HEX="$(od -An -N4 -tx1 "$FIRST_CORRUPTED_CACHE" | tr -d ' \n')"
    if [ "$RECOVERY_MAGIC_HEX" = "00000000" ] || [ -z "$RECOVERY_MAGIC_HEX" ]; then
        echo "FAIL: corrupted cache entry was not rewritten after recovery" >&2
        FAIL_KIND="incremental-cache-recovery-failed"
        exit 1
    fi
fi

echo "=== All incremental stages passed ==="
echo "incremental-compilation-gate=pass"

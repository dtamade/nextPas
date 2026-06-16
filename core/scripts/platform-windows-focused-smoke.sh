#!/bin/bash
# Windows focused-runtime smoke — cross-compile, SCP, SSH execute on real Windows VM
#
# This script distinguishes between two test categories:
#   - Wine tests (*_wine): validate cross-compilation and basic behavior under Wine.
#     Good for CI on Linux — catches regressions early.
#   - Real Windows tests (*_windows_real): exercises Windows-only APIs (IOCP, Winsock2,
#     registered I/O) that Wine does not faithfully emulate. Requires a real Windows VM.
#
# Usage:
#   ./scripts/platform-windows-focused-smoke.sh [OPTIONS]
#
# Options:
#   --list                 List all discovered test modules (Wine + Real Windows)
#   --list-real            List only Real Windows test modules
#   --module NAME          Build and run a single module on the VM
#   --windows-real-only    Run only Real Windows tests (requires real Windows VM)
#   --all                  Run ALL tests — both Wine and Real Windows
#   --help                 Show this help message
#
# Prerequisites:
#   - fpc -Twin64 cross-compiler
#   - Windows VM with SSH server running
#   - SSH key at ~/.ssh/windows_vm (or set WIN_SSH_KEY)
#
# Config — set via environment variables:
VM_USER="${WIN_USER:-dtamade}"
VM_HOST="${WIN_HOST:-192.168.122.208}"
VM_DIR='C:\Users\dtamade\Desktop\win-rt'
SSH_KEY="${WIN_SSH_KEY:-/tmp/win-setup/id_rsa}"
CORE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/../build"
mkdir -p "$LOG_DIR"

# ── Module discovery ────────────────────────────────────────────────

# Discover all test modules: *_wine and *_windows_real directories with a Makefile
list_modules() {
    {
        find "$CORE_ROOT/tests" -path '*_wine/*' -name 'Makefile'
        find "$CORE_ROOT/tests" -path '*_windows_real/*' -name 'Makefile'
    } | sort | while read mk; do basename "$(dirname "$mk")"; done
}

# Discover only Real Windows modules (*_windows_real)
list_real_modules() {
    find "$CORE_ROOT/tests" -path '*_windows_real/*' -name 'Makefile' | sort \
        | while read mk; do basename "$(dirname "$mk")"; done
}

# ── Build & run helpers ─────────────────────────────────────────────

# Cross-compile a module.  Handles two Makefile layouts:
#   - Wine modules (and *_windows_real with wine-build target): use `make wine-build`
#   - _windows_real with only `build` target: use `make build` (already cross-compiles)
build_module() {
    local DIR="$1"
    local MOD_NAME
    MOD_NAME=$(basename "$DIR")
    local LOG_FILE="$LOG_DIR/${MOD_NAME}_build.log"
    if grep -q '^wine-build:' "$DIR/Makefile" 2>/dev/null; then
        make -C "$DIR" wine-build >"$LOG_FILE" 2>&1
    else
        make -C "$DIR" build >"$LOG_FILE" 2>&1
    fi
    if [ $? -ne 0 ]; then
        echo "BUILD FAIL: $MOD_NAME (see $LOG_FILE)"
        return 1
    fi
    grep -q 'Linking' "$LOG_FILE"
}

# Locate the built .exe for a module.
find_exe() {
    local NAME="$1"
    local EXE=""
    # 1) Try *_wine_win64 layout (wine-build target)
    EXE=$(find "$CORE_ROOT/build" -path "*${NAME}_wine_win64/*" -name '*.exe' 2>/dev/null | head -1)
    # 2) Fallback: look for any .exe under the module build dir
    if [ -z "$EXE" ]; then
        EXE=$(find "$CORE_ROOT/build" -path "*${NAME}/*" -name '*.exe' 2>/dev/null | head -1)
    fi
    echo "$EXE"
}

# Build, SCP to VM, run, and print the result line.
run_module() {
    local NAME="$1"
    local mk
    mk=$(find "$CORE_ROOT/tests" -path "*${NAME}*" -name 'Makefile' | head -1)
    [ -z "$mk" ] && return 1

    local DIR
    DIR=$(dirname "$mk")
    printf "%-45s" "[build] $NAME"

    if ! build_module "$DIR"; then
        echo "BUILD FAIL"
        return 2
    fi

    local EXE
    EXE=$(find_exe "$NAME")
    if [ -z "$EXE" ]; then
        echo "NO EXE"
        return 3
    fi

    # Copy to VM
    ssh -o StrictHostKeyChecking=no -o BatchMode=yes -i "$SSH_KEY" "$VM_USER@$VM_HOST" \
        "mkdir ${VM_DIR} -Force" 2>/dev/null

    scp -q -o StrictHostKeyChecking=no -o BatchMode=yes -i "$SSH_KEY" \
        "$EXE" "$VM_USER@$VM_HOST":"${VM_DIR}\\${NAME}.exe"

    # Run on VM and capture the summary line
    local RESULT_LINE
    RESULT_LINE=$(ssh -o StrictHostKeyChecking=no -o BatchMode=yes -i "$SSH_KEY" \
        "$VM_USER@$VM_HOST" "${VM_DIR}\\${NAME}.exe" 2>&1 | grep -oP '\d+ total, \d+ passed, \d+ failed')

    echo "$RESULT_LINE"
}

# ── Run a set of modules and print summary ──────────────────────────

run_module_set() {
    local LABEL="$1"
    shift
    local MODULES=("$@")

    echo "=== Windows Focused Runtime Smoke — ${LABEL} ==="
    echo ""

    PASS=0; FAIL=0; TOTAL=0
    for NAME in "${MODULES[@]}"; do
        TOTAL=$((TOTAL + 1))
        RESULT=$(run_module "$NAME" 2>&1)
        echo "  $RESULT"
        if echo "$RESULT" | grep -qP '0 failed'; then
            PASS=$((PASS + 1))
        else
            FAIL=$((FAIL + 1))
        fi
    done

    echo ""
    echo "=== Results: $PASS passed, $FAIL failed, $TOTAL total ==="
    [ "$FAIL" -eq 0 ]
}

# ── Main ────────────────────────────────────────────────────────────

case "${1:-}" in
    --help|-h)
        sed -n '2,/^# Config/p' "$0" | grep '^#' | sed 's/^# \?//'
        exit 0
        ;;
    --list)
        list_modules
        exit 0
        ;;
    --list-real)
        list_real_modules
        exit 0
        ;;
    --module)
        shift
        run_module "$1"
        exit $?
        ;;
    --windows-real-only)
        mapfile -t REAL_MODULES < <(list_real_modules)
        if [ ${#REAL_MODULES[@]} -eq 0 ]; then
            echo "No *_windows_real test modules found."
            exit 1
        fi
        run_module_set "Real Windows" "${REAL_MODULES[@]}"
        exit $?
        ;;
    --all)
        mapfile -t ALL_MODULES < <(list_modules)
        if [ ${#ALL_MODULES[@]} -eq 0 ]; then
            echo "No test modules found."
            exit 1
        fi
        run_module_set "All (Wine + Real Windows)" "${ALL_MODULES[@]}"
        exit $?
        ;;
    *)
        # Default (no flag): run Wine modules only (backward-compatible)
        mapfile -t WINE_MODULES < <(
            find "$CORE_ROOT/tests" -path '*_wine/*' -name 'Makefile' | sort \
                | while read mk; do basename "$(dirname "$mk")"; done
        )
        if [ ${#WINE_MODULES[@]} -eq 0 ]; then
            echo "No *_wine test modules found."
            exit 1
        fi
        run_module_set "Wine" "${WINE_MODULES[@]}"
        exit $?
        ;;
esac

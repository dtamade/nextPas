#!/bin/bash
# Windows focused-runtime smoke — cross-compile, SCP, SSH execute on real Windows VM
#
# Usage:
#   ./scripts/platform-windows-focused-smoke.sh [--module NAME] [--list]
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

list_modules() {
    find "$CORE_ROOT/tests" -path '*_wine/*' -name 'Makefile' | sort \
        | while read mk; do basename "$(dirname "$mk")"; done
}

run_module() {
    local NAME="$1"
    local mk
    mk=$(find "$CORE_ROOT/tests" -path "*${NAME}*" -name 'Makefile' | head -1)
    [ -z "$mk" ] && return 1

    local DIR
    DIR=$(dirname "$mk")
    printf "%-45s" "[build] $NAME"

    if ! make -C "$DIR" wine-build 2>/dev/null | grep -q 'Linking'; then
        echo "BUILD FAIL"
        return 2
    fi

    local EXE
    EXE=$(find "$CORE_ROOT/build" -path "*${NAME}_wine_win64/*" -name '*.exe' | head -1)
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

# Main
case "${1:-}" in
    --list)
        list_modules
        exit 0
        ;;
    --module)
        shift
        run_module "$1"
        exit $?
        ;;
    *)
        echo "=== Windows Focused Runtime Smoke ==="
        echo ""

        PASS=0; FAIL=0; TOTAL=0
        for mk in $(find "$CORE_ROOT/tests" -path '*_wine/*' -name 'Makefile' | sort); do
            TOTAL=$((TOTAL + 1))
            NAME=$(basename "$(dirname "$mk")")
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
        ;;
esac

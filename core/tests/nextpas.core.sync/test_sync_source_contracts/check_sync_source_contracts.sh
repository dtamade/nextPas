#!/usr/bin/env bash
# Source-contract gate for nextpas.core.sync — prevents facade/API drift.
set -euo pipefail

CORE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SRC="$CORE_ROOT/src"
FACADE="$SRC/nextpas.core.sync.pas"
INTF="$SRC/nextpas.core.sync.intf.pas"
MUTEX="$SRC/nextpas.core.sync.mutex.pas"
CONDVAR="$SRC/nextpas.core.sync.condvar.pas"
POOL="$SRC/nextpas.core.sync.pool.pas"

fail() {
  echo "[sync-source-contract] FAIL: $*" >&2
  exit 1
}

require_file() {
  local f="$1"
  [[ -f "$f" ]] || fail "missing file: $f"
}

require_token() {
  local file="$1"
  local token="$2"
  rg -F --quiet -- "$token" "$file" || fail "missing in $(basename "$file"): $token"
}

forbid_token() {
  local file="$1"
  local token="$2"
  if rg -F --quiet -- "$token" "$file"; then
    fail "forbidden token in $(basename "$file"): $token"
  fi
}

require_file "$FACADE"
require_file "$INTF"
require_file "$MUTEX"
require_file "$CONDVAR"
require_file "$POOL"

# --- Facade factories (stable public surface) ---
for factory in \
  'function Mutex: INativeMutex' \
  'function FutexMutex: IMutex' \
  'function RWLock: IRWLock' \
  'function WaitGroup: IWaitGroup' \
  'function CondVar: ICondVar' \
  'function Once: IOnce' \
  'function SpinLock: ISpinLock' \
  'function Semaphore' \
  'function Barrier' \
  'function Event'
do
  require_token "$FACADE" "$factory"
done

# Facade must not pull experimental pool into the public re-export surface.
forbid_token "$FACADE" 'nextpas.core.sync.pool'
forbid_token "$FACADE" 'TSyncPool'
forbid_token "$FACADE" 'CreateSyncPool'

# --- Interfaces (live names; reject retired doc aliases) ---
for iface in ILock IMutex INativeMutex IRWLock IWaitGroup ICondVar IOnce ISpinLock ISemaphore IBarrier IEvent ILockGuard; do
  require_token "$INTF" "$iface"
done
forbid_token "$INTF" 'ILockable'
forbid_token "$INTF" 'IRWLockable'

require_token "$INTF" 'procedure Do_'
require_token "$INTF" 'function WaitTimeout'
require_token "$INTF" 'INativeMutex'
require_token "$INTF" 'procedure Wait(const AMutex: INativeMutex)'
require_token "$INTF" 'function NativeHandle: Pointer'

# IMutex block (until next type) must not contain NativeHandle
if awk '
  /^[[:space:]]*IMutex = interface\(/ { in_mutex=1; next }
  in_mutex && /^[[:space:]]*INativeMutex = interface/ { exit }
  in_mutex && /function NativeHandle/ { found=1 }
  END { exit(found ? 0 : 1) }
' "$INTF"; then
  fail "IMutex must not declare NativeHandle (use INativeMutex)"
fi

# --- Mutex default is ERRORCHECK (non-recursive); Futex is not native ---
require_token "$MUTEX" 'PLATFORM_MUTEX_ERRORCHECK'
require_token "$MUTEX" 'TFutexMutex'
require_token "$MUTEX" 'INativeMutex'
# TFutexMutex class line must not list INativeMutex
if rg -n 'TFutexMutex = class' "$MUTEX" | rg -F 'INativeMutex' >/dev/null; then
  fail "TFutexMutex must not implement INativeMutex"
fi

# --- CondVar pairs only with INativeMutex (no runtime Futex check needed) ---
require_token "$CONDVAR" 'INativeMutex'
forbid_token "$CONDVAR" 'CheckNotFutexMutex'
forbid_token "$CONDVAR" 'TFutexMutex'

# --- L1 implementations must not use FPC platform units directly ---
shopt -s nullglob
for unit in "$SRC"/nextpas.core.sync*.pas; do
  base="$(basename "$unit")"
  for banned in \
    'uses Windows' \
    ', Windows' \
    'uses BaseUnix' \
    ', BaseUnix' \
    'uses PThreads' \
    ', PThreads' \
    'uses UnixType' \
    ', UnixType' \
    'uses Linux' \
    ', Linux'
  do
    if rg -n -- "$banned" "$unit" >/dev/null 2>&1; then
      if rg -n -- "$banned" "$unit" | rg -v '^\s*[0-9]+:\s*//' | rg -v '^\s*[0-9]+:\s*\{' >/dev/null 2>&1; then
        fail "$base must not depend on FPC platform unit ($banned); use platform.sync"
      fi
    fi
  done
done

# --- Pool: IMutex cold path + per-pool TLS ---
require_token "$POOL" 'IMutex'
require_token "$POOL" 'TMutex.Create'
require_token "$POOL" 'threadvar'
require_token "$POOL" 'GPoolTlsList'
require_token "$POOL" 'Owner'
for banned_cs in TRTLCriticalSection InitCriticalSection EnterCriticalSection LeaveCriticalSection DoneCriticalSection; do
  forbid_token "$POOL" "$banned_cs"
done

echo "sync-source-contract=pass"

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
  'function Mutex: IMutex' \
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
for iface in ILock IMutex IRWLock IWaitGroup ICondVar IOnce ISpinLock ISemaphore IBarrier IEvent ILockGuard; do
  require_token "$INTF" "$iface"
done
forbid_token "$INTF" 'ILockable'
forbid_token "$INTF" 'IRWLockable'

require_token "$INTF" 'procedure Do_'
require_token "$INTF" 'function WaitTimeout'
require_token "$INTF" 'function NativeHandle: Pointer'

# --- Mutex default is ERRORCHECK (non-recursive) ---
require_token "$MUTEX" 'PLATFORM_MUTEX_ERRORCHECK'
require_token "$MUTEX" 'TFutexMutex'

# --- CondVar refuses FutexMutex pairing ---
require_token "$CONDVAR" 'CheckNotFutexMutex'
require_token "$CONDVAR" 'TFutexMutex'

# --- L1 implementations must not use FPC platform units directly ---
# (pool is the known-debt exception and is checked separately.)
shopt -s nullglob
for unit in "$SRC"/nextpas.core.sync*.pas; do
  base="$(basename "$unit")"
  case "$base" in
    nextpas.core.sync.pool.pas) continue ;;
  esac
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
      # Allow only if it is a comment line
      if rg -n -- "$banned" "$unit" | rg -v '^\s*[0-9]+:\s*//' | rg -v '^\s*[0-9]+:\s*\{' >/dev/null 2>&1; then
        fail "$base must not depend on FPC platform unit ($banned); use platform.sync"
      fi
    fi
  done
done

# --- Pool cold path uses nextpas IMutex (no FPC CriticalSection) ---
require_token "$POOL" 'IMutex'
require_token "$POOL" 'TMutex.Create'
require_token "$POOL" 'threadvar'
for banned_cs in TRTLCriticalSection InitCriticalSection EnterCriticalSection LeaveCriticalSection DoneCriticalSection; do
  forbid_token "$POOL" "$banned_cs"
done

echo "sync-source-contract=pass"

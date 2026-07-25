#!/usr/bin/env bash
# Source-contract gate for nextpas.core.sync — prevents facade/API drift.
set -euo pipefail

CORE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SRC="$CORE_ROOT/src"
FACADE="$SRC/nextpas.core.sync.pas"
INTF="$SRC/nextpas.core.sync.intf.pas"
MUTEX="$SRC/nextpas.core.sync.mutex.pas"
RWLOCK="$SRC/nextpas.core.sync.rwlock.pas"
CONDVAR="$SRC/nextpas.core.sync.condvar.pas"
ONCE="$SRC/nextpas.core.sync.once.pas"
WAITGROUP="$SRC/nextpas.core.sync.waitgroup.pas"
ERRORS="$SRC/nextpas.core.sync.errors.pas"
POOL="$SRC/nextpas.core.sync.pool.pas"
TESTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE_MK="$TESTS_ROOT/Makefile"
EXAMPLE_LPR="$CORE_ROOT/examples/nextpas.core.sync/sync_basics/sync_basics.lpr"
BENCH_LPR="$CORE_ROOT/benchmarks/nextpas.core.sync/bench_sync/bench_sync.lpr"

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

# Match real unit references in uses / fully-qualified names (not comments).
forbid_unit_ref() {
  local file="$1"
  local unit="$2"
  if rg -n -- "\b${unit}\b" "$file" | rg -v '^\s*[0-9]+:\s*//' | rg -v '^\s*[0-9]+:\s*\{' | rg -v '^\s*[0-9]+:\s*\(\*' >/dev/null 2>&1; then
    fail "$(basename "$file") must not reference FPC unit ${unit}"
  fi
}

require_file "$FACADE"
require_file "$INTF"
require_file "$MUTEX"
require_file "$RWLOCK"
require_file "$CONDVAR"
require_file "$ONCE"
require_file "$WAITGROUP"
require_file "$ERRORS"
require_file "$POOL"
require_file "$MODULE_MK"
require_file "$EXAMPLE_LPR"
require_file "$BENCH_LPR"

# --- Facade factories (stable public surface) ---
for factory in \
  'function Mutex: INativeMutex' \
  'function RecursiveMutex: INativeMutex' \
  'function FutexMutex: IMutex' \
  'function RWLock: IRWLock' \
  'function WaitGroup: IWaitGroup' \
  'function CondVar: ICondVar' \
  'function Once: IOnce' \
  'function SpinLock: ISpinLock' \
  'function Semaphore' \
  'function Barrier' \
  'function Event' \
  'function Latch' \
  'function Notify' \
  'function Channel' \
  'function CreateSyncPool' \
  'procedure WithLock' \
  'procedure WithReadLock' \
  'procedure WithWriteLock'
do
  require_token "$FACADE" "$factory"
done

# Pool is advanced facade re-export (CONTRACT 1.5+); errors stay internal.
require_token "$FACADE" 'nextpas.core.sync.pool'
require_token "$FACADE" 'TSyncPool'
require_token "$FACADE" 'CreateSyncPool'
forbid_token "$FACADE" 'nextpas.core.sync.errors'
forbid_token "$FACADE" 'SyncRaise'

# --- Interfaces (live names; reject retired doc aliases) ---
for iface in ILock IMutex INativeMutex IRWLock IWaitGroup ICondVar IOnce ISpinLock ISemaphore IBarrier IEvent ILatch INotify IChannel ILockGuard; do
  require_token "$INTF" "$iface"
done
forbid_token "$INTF" 'ILockable'
forbid_token "$INTF" 'IRWLockable'

require_token "$INTF" 'procedure Do_'
require_token "$INTF" 'procedure DoOnce'
require_token "$INTF" 'procedure DoOnce(const AProc: TSyncProc)'
# Do_ public name stays frozen (DoOnce is alias + TSyncProc overload)
require_file "$SRC/nextpas.core.sync.base.pas"
require_token "$SRC/nextpas.core.sync.base.pas" 'csrTimeout'
require_token "$SRC/nextpas.core.sync.base.pas" 'crrTimeout'
require_file "$SRC/nextpas.core.sync.latch.pas"
require_file "$SRC/nextpas.core.sync.notify.pas"
require_file "$SRC/nextpas.core.sync.channel.pas"
require_file "$SRC/nextpas.core.sync.scoped.pas"
require_token "$INTF" 'function WaitTimeout'
require_token "$INTF" 'INativeMutex'
require_token "$INTF" 'procedure Wait(const AMutex: INativeMutex)'
require_token "$INTF" 'function NativeHandle: Pointer'
require_token "$INTF" 'TDuration'
require_token "$INTF" 'function WaitTimeout(const ATimeout: TDuration): Boolean'
require_token "$INTF" 'function WaitTimeout(const AMutex: INativeMutex; const ATimeout: TDuration): Boolean'
require_token "$INTF" 'function TryAcquireTimeout(const ATimeout: TDuration): Boolean'

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
require_token "$MUTEX" 'PLATFORM_MUTEX_RECURSIVE'
require_token "$MUTEX" 'TFutexMutex'
require_token "$MUTEX" 'TRecursiveMutex'
require_token "$MUTEX" 'INativeMutex'
# TFutexMutex class line must not list INativeMutex
if rg -n 'TFutexMutex = class' "$MUTEX" | rg -F 'INativeMutex' >/dev/null; then
  fail "TFutexMutex must not implement INativeMutex"
fi
# TRecursiveMutex must implement INativeMutex
if ! rg -n 'TRecursiveMutex = class' "$MUTEX" | rg -F 'INativeMutex' >/dev/null; then
  fail "TRecursiveMutex must implement INativeMutex"
fi

# FHandle must be under private (not public) for platform-backed primitives
for f in "$MUTEX" "$RWLOCK" "$CONDVAR"; do
  if ! awk '
    BEGIN { priv=0; ok=0 }
    /private/ { priv=1 }
    /public/ { priv=0 }
    priv && /FHandle/ { ok=1 }
    END { exit(ok ? 0 : 1) }
  ' "$f"; then
    fail "$(basename "$f"): FHandle must appear in a private section"
  fi
  if awk '
    BEGIN { pub=0; bad=0 }
    /public/ { pub=1 }
    /private/ { pub=0 }
    /protected/ { pub=0 }
    pub && /FHandle[[:space:]]*:/ { bad=1 }
    END { exit(bad ? 0 : 1) }
  ' "$f"; then
    fail "$(basename "$f"): FHandle must not be public"
  fi
done

# --- CondVar pairs only with INativeMutex; timeout vs platform error ---
require_token "$CONDVAR" 'INativeMutex'
require_token "$CONDVAR" 'PLATFORM_ERR_TIMEDOUT'
require_token "$CONDVAR" 'SyncRaiseOpFailed'
forbid_token "$CONDVAR" 'CheckNotFutexMutex'
forbid_token "$CONDVAR" 'TFutexMutex'

# --- Once / WaitGroup ergonomics ---
require_token "$ONCE" 'procedure DoOnce'
require_token "$WAITGROUP" 'function WaitTimeout(const ATimeout: TDuration): Boolean'
require_token "$WAITGROUP" 'function WaitTimeout(const ATimeoutNs: Int64): Boolean'

# --- Unified errors helper ---
require_token "$ERRORS" 'SyncRaiseOpFailed'
require_token "$ERRORS" 'SyncRaiseArg'
require_token "$ERRORS" 'SyncRaiseInvalidOp'
require_token "$MUTEX" 'SyncRaiseOpFailed'
require_token "$RWLOCK" 'SyncRaiseOpFailed'
require_token "$CONDVAR" 'SyncRaiseOpFailed'

# Destroy surfaces platform errors (message still contains "Destroy failed")
for f in "$MUTEX" "$RWLOCK" "$CONDVAR"; do
  require_token "$f" 'Destroy'
  require_token "$f" 'LRet <> 0'
done

# --- Compile-gate matrix present in module Makefile ---
for gate in \
  test_sync_windows_compile_gate \
  test_sync_darwin_compile_gate \
  test_sync_freebsd_compile_gate \
  test_sync_android_compile_gate
do
  require_token "$MODULE_MK" "$gate"
  require_file "$TESTS_ROOT/$gate/Makefile"
done

# --- L1 implementations must not use FPC platform units or RTL sync stack ---
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
  for banned_rtl in SysUtils Classes SyncObjs; do
    forbid_unit_ref "$unit" "$banned_rtl"
  done
done

# --- Tests / example / bench: no FPC Classes/SysUtils/SyncObjs ---
for consumer in \
  "$TESTS_ROOT/test_sync/test_sync.lpr" \
  "$TESTS_ROOT/test_sync_pool/test_sync_pool.lpr" \
  "$EXAMPLE_LPR" \
  "$BENCH_LPR"
do
  require_file "$consumer"
  for banned_rtl in SysUtils Classes SyncObjs; do
    forbid_unit_ref "$consumer" "$banned_rtl"
  done
  # Prefer nextpas thread model when threads are used
  if rg -F --quiet 'TWorkerThread\|TThread\|CreateAnonymousThread\|FreeOnTerminate' "$consumer"; then
    if rg -F --quiet 'TThread\|CreateAnonymousThread\|FreeOnTerminate' "$consumer"; then
      if ! rg -F --quiet 'TWorkerThread' "$consumer"; then
        fail "$(basename "$consumer"): threaded consumer must use TWorkerThread, not FPC TThread"
      fi
      if rg -n -- 'TThread\.|CreateAnonymousThread|FreeOnTerminate' "$consumer" | rg -v '^\s*[0-9]+:\s*//' >/dev/null 2>&1; then
        fail "$(basename "$consumer"): forbidden FPC TThread API (use TWorkerThread)"
      fi
    fi
  fi
done

# Explicit positive: tests/example must reference TWorkerThread when multi-threaded
require_token "$TESTS_ROOT/test_sync/test_sync.lpr" 'TWorkerThread'
require_token "$TESTS_ROOT/test_sync_pool/test_sync_pool.lpr" 'TWorkerThread'
require_token "$EXAMPLE_LPR" 'TWorkerThread'
require_token "$BENCH_LPR" 'TWorkerThread'

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

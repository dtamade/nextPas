#!/usr/bin/env bash
# Source-contract hard gate for B13 pooled WithTransaction lease-linger.
# heaptrc cannot catch closure-captured lease (not heap leak); this script
# hard-gates the discipline that pooled paths must use TDbConnProc param form.
# See core/src/nextpas.core.db.pas:148-152, core/src/nextpas.core.db.tx.pas,
# core/docs/db/CONTRACT.md §2.3/§2.7, core/docs/db/pool.md §2.
set -euo pipefail
CORE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SRC="$CORE_ROOT/src"
FACADE="$SRC/nextpas.core.db.pas"
TX="$SRC/nextpas.core.db.tx.pas"
POOL_MD="$CORE_ROOT/docs/db/pool.md"
CONTRACT="$CORE_ROOT/docs/db/CONTRACT.md"
FACTORY_MK="$(dirname "${BASH_SOURCE[0]}")/Makefile"

fail() { echo "[pool-lease-source-contract] FAIL: $*" >&2; exit 1; }
require_token() { rg -F --quiet -- "$2" "$1" || fail "missing token in $(basename "$1"): $2"; }
forbid_token() { if rg -F --quiet -- "$2" "$1"; then fail "forbidden token in $(basename "$1"): $2"; fi; }

# 1. capturing overload hard-gated: facade must not expose TDbTxProc (heaptrc blind spot); tx keeps deprecated as single-source warning for non-pooled direct use
if rg -n "procedure WithTransaction\(.*TDbTxProc" "$FACADE" >/dev/null 2>&1; then fail "facade must not expose TDbTxProc capture form (B13 lease linger; heaptrc not covering)"; fi
if rg -n "procedure WithTransactionRetry\(.*TDbTxProc" "$FACADE" >/dev/null 2>&1; then fail "facade must not expose TDbTxProc capture form"; fi
require_token "$TX" "deprecated 'pooled: use TDbConnProc overload (B13 lease linger; heaptrc not covering)'"
# facade header and tx comment must declare source-contract hard gate (not doc-only)
require_token "$FACADE" "source-contract 硬门禁"
forbid_token "$FACADE" "仅文档门禁"
require_token "$TX" "source-contract 硬门禁"
forbid_token "$TX" "仅文档门禁"
require_token "$POOL_MD" "source-contract 硬门禁"
forbid_token "$POOL_MD" "仅文档门禁"
require_token "$CONTRACT" "source-contract 硬门禁"
forbid_token "$CONTRACT" "仅文档门禁"
# also forbid doc-only phrase in those files (heaptrc blind spot must be hard-gated)
# (already forbid via forbid_token above)

# 2. pool impl must not use capturing form (TDbTxProc) — pooled paths zero capture
if rg -n "TDbTxProc" "$SRC/nextpas.core.db.pool.pas" >/dev/null 2>&1; then fail "pool facade must not use TDbTxProc (use TDbConnProc)"; fi
if rg -n "TDbTxProc" "$SRC/nextpas.core.db.pool.impl.pas" >/dev/null 2>&1; then fail "pool impl must not use TDbTxProc"; fi
# pool/* must not directly call capturing WithTransaction — pooled paths use ScopedLease/TDbConnProc
if rg -n "WithTransaction" "$SRC/nextpas.core.db.pool"*.pas >/dev/null 2>&1; then fail "pool must not directly call WithTransaction (use ScopedLease)"; fi

# 3. hygiene zero artifact (conceptual pass) — no .o/.ppu stray in src
if find "$SRC" -maxdepth 1 -type f \( -name '*.o' -o -name '*.ppu' \) -print -quit | grep -q .; then
  fail " hygiene: .o/.ppu stray in core/src"
fi

# 4. Makefile must hard-gate via heaptrc + source-contract (not heaptrc alone)
require_token "$FACTORY_MK" "heaptrc"
require_token "$FACTORY_MK" "check_pool_lease_source_contract.sh"

# 5. bytes.ops single source invariant still holds (owner=bytes.ops):
#    哨兵常量已随 bytes.ops 新版退役，门禁改为检查真实机制——实现层必须
#    uses bytes.ops，且门面三文件零裸 Move（拷贝经 BytesCopy、增长经
#    BytesGrowCapacity 单源，不自建副本）。
forbid_token "$FACADE" "Move("
forbid_token "$SRC/nextpas.core.db.pool.pas" "Move("
forbid_token "$SRC/nextpas.core.db.pool.impl.pas" "Move("
require_token "$SRC/nextpas.core.db.pool.pas" "nextpas.core.bytes.ops"
require_token "$SRC/nextpas.core.db.pool.impl.pas" "nextpas.core.bytes.ops"
require_token "$FACADE" "nextpas.core.db.bulk"

# 6. stability: pool ScopedLease must be try..finally nil return (resource not lost)
require_token "$SRC/nextpas.core.db.pool.impl.pas" "try"
require_token "$SRC/nextpas.core.db.pool.impl.pas" "LConn := nil"

echo "pool-lease-source-contract=pass"

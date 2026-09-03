#!/usr/bin/env bash
# Source-contract gate for nextpas.core.db facade discipline.
# Guards: L3 facade pure re-export inline thin forward via factory.facade,
#         zero adapter hard link (trimmable), bytes.ops single source,
#         and design-conventions.md:129 inline red line 2 (loop/SIMD body not inline).
#         体积分治：factory.facade 聚合门面 + 6 后端 + 池独立单元 <800 软阈隔离
set -euo pipefail
CORE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SRC="$CORE_ROOT/src"
FACADE="$SRC/nextpas.core.db.pas"
FACTORY_FACADE="$SRC/nextpas.core.db.factory.facade.pas"
FACTORY_FACADE_SQLITE="$SRC/nextpas.core.db.factory.facade.sqlite.pas"
FACTORY_FACADE_PG="$SRC/nextpas.core.db.factory.facade.pg.pas"
FACTORY_FACADE_MYSQL="$SRC/nextpas.core.db.factory.facade.mysql.pas"
FACTORY_FACADE_ODBC="$SRC/nextpas.core.db.factory.facade.odbc.pas"
FACTORY_FACADE_REDIS="$SRC/nextpas.core.db.factory.facade.redis.pas"
FACTORY_FACADE_DM="$SRC/nextpas.core.db.factory.facade.dm.pas"
FACTORY_FACADE_POOL="$SRC/nextpas.core.db.factory.facade.pool.pas"
DESIGN_CONV="$CORE_ROOT/docs/design-conventions.md"
fail() { echo "[db-facade-source-contract] FAIL: $*" >&2; exit 1; }
require_file() { [[ -f "$1" ]] || fail "missing file: $1"; }
require_token() { rg -F --quiet -- "$2" "$1" || fail "missing token in $(basename "$1"): $2"; }
forbid_token() { if rg -F --quiet -- "$2" "$1"; then fail "forbidden token in $(basename "$1"): $2"; fi; }
forbid_regex() { if rg --quiet -- "$2" "$1"; then fail "forbidden regex in $(basename "$1"): $2"; fi; }

require_file "$FACADE"
require_file "$FACTORY_FACADE"
require_file "$DESIGN_CONV"
# 体积分治单源文件均需存在
for f in "$FACTORY_FACADE_SQLITE" "$FACTORY_FACADE_PG" "$FACTORY_FACADE_MYSQL" "$FACTORY_FACADE_ODBC" "$FACTORY_FACADE_REDIS" "$FACTORY_FACADE_DM" "$FACTORY_FACADE_POOL"; do
  require_file "$f"
done

# --- 1. bytes.ops single source (owner=bytes.ops): uses-link + zero direct Move/SetLength ---
# NOTE (2026-09-03 consolidation): compile-time {$IF} sentinel aliases retired — the
# sentinel symbol no longer exists in bytes.ops. Single-source is enforced by uses-link
# (FPC resolves the single owner unit) + forbidding direct Move/SetLength in thin
# facade implementations (all bulk copy/alloc lives in the owner) + FPC compile itself.
require_token "$FACADE" 'nextpas.core.bytes.ops'
require_token "$FACADE" 'nextpas.core.db.perf'
require_token "$FACTORY_FACADE" 'nextpas.core.bytes.ops'
for f in "$FACTORY_FACADE_SQLITE" "$FACTORY_FACADE_PG" "$FACTORY_FACADE_MYSQL" "$FACTORY_FACADE_ODBC" "$FACTORY_FACADE_REDIS" "$FACTORY_FACADE_DM" "$FACTORY_FACADE_POOL"; do
  require_token "$f" 'nextpas.core.bytes.ops'
done
for f in "$FACADE" "$FACTORY_FACADE" "$FACTORY_FACADE_SQLITE" "$FACTORY_FACADE_PG" "$FACTORY_FACADE_MYSQL" "$FACTORY_FACADE_ODBC" "$FACTORY_FACADE_REDIS" "$FACTORY_FACADE_DM" "$FACTORY_FACADE_POOL"; do
  IMPL_USES_BODY=$(sed -n '/^implementation/,/^end\./p' "$f")
  if echo "$IMPL_USES_BODY" | rg -n -- '\bMove\s*\(' >/dev/null; then
    fail "facade implementation must not contain direct Move (single source belongs to bytes.ops): $(basename "$f")"
  fi
  if echo "$IMPL_USES_BODY" | rg -n -- '\bSetLength\s*\(' >/dev/null; then
    fail "facade implementation must not contain direct SetLength (single source belongs to bytes.ops): $(basename "$f")"
  fi
done

# --- 1b. 体积分治软阈 800 行隔离（聚合门面 <150，每后端 <100） ---
for f in "$FACTORY_FACADE_SQLITE" "$FACTORY_FACADE_PG" "$FACTORY_FACADE_MYSQL" "$FACTORY_FACADE_ODBC" "$FACTORY_FACADE_REDIS" "$FACTORY_FACADE_DM" "$FACTORY_FACADE_POOL"; do
  lines=$(wc -l < "$f")
  if [ "$lines" -gt 100 ]; then
    fail "per-backend facade subunit must be <100 lines (800 soft threshold分治): $(basename "$f") has $lines"
  fi
done
agg_lines=$(wc -l < "$FACTORY_FACADE")
if [ "$agg_lines" -gt 200 ]; then
  fail "aggregator facade must be <200 lines (800 soft threshold分治): factory.facade.pas has $agg_lines"
fi

# --- 2. facade pure re-export discipline (zero adapter hard link, via factory.facade) ---
require_token "$FACADE" 'Facade pure re-export: inline thin forward via factory.facade Kind-driven table, zero adapter hard link'
require_token "$FACADE" 'nextpas.core.db.factory.facade'
# 分治聚合注释
require_token "$FACTORY_FACADE" '体积分治'
require_token "$FACTORY_FACADE" '软阈'
# implementation uses must not hard link adapters (trimmable invariant)
IMPL_USES=$(sed -n '/^implementation/,/^end\./p' "$FACADE")
for unit in 'nextpas.core.db.sqlite.adapter' 'nextpas.core.db.pg.adapter' 'nextpas.core.db.mysql.adapter' 'nextpas.core.db.odbc.adapter' 'nextpas.core.db.redis.adapter' 'nextpas.core.db.dm.adapter' 'nextpas.core.db.factory.register'; do
  if echo "$IMPL_USES" | rg -F --quiet -- "$unit"; then
    fail "facade implementation must not hard link adapter: $unit (use factory.facade Kind-driven)"
  fi
done
# 每后端分治单元亦必须零 adapter 硬链接
for f in "$FACTORY_FACADE_SQLITE" "$FACTORY_FACADE_PG" "$FACTORY_FACADE_MYSQL" "$FACTORY_FACADE_ODBC" "$FACTORY_FACADE_REDIS" "$FACTORY_FACADE_DM"; do
  if rg -F --quiet -- "nextpas.core.db." "$f" | rg -F --quiet -- ".adapter"; then
    # allow no adapter hard link, but fail if any adapter found
    if rg -n 'adapter' "$f" >/dev/null; then
      # check specific adapter string not in uses
      for unit in 'nextpas.core.db.sqlite.adapter' 'nextpas.core.db.pg.adapter' 'nextpas.core.db.mysql.adapter' 'nextpas.core.db.odbc.adapter' 'nextpas.core.db.redis.adapter' 'nextpas.core.db.dm.adapter'; do
        if rg -F --quiet -- "$unit" "$f"; then
          fail "per-backend facade subunit must not hard link adapter: $unit in $(basename "$f")"
        fi
      done
    fi
  fi
done
# aggregator implementation uses must delegate to per-backend subunits, not adapters
AGG_IMPL=$(sed -n '/^implementation/,/^end\./p' "$FACTORY_FACADE")
for sub in 'nextpas.core.db.factory.facade.sqlite' 'nextpas.core.db.factory.facade.pg' 'nextpas.core.db.factory.facade.mysql' 'nextpas.core.db.factory.facade.odbc' 'nextpas.core.db.factory.facade.redis' 'nextpas.core.db.factory.facade.dm' 'nextpas.core.db.factory.facade.pool'; do
  require_token "$FACTORY_FACADE" "$sub"
done
# interface must not directly import adapter either
if rg -n '^[[:space:]]*nextpas\.core\.db\.(sqlite|pg|mysql|odbc|redis|dm)\.adapter' "$FACADE" >/dev/null; then
  fail "facade interface must not import adapter units"
fi

# --- 3. inline thin forward surface ---
# NOTE: declarations may span lines — join newlines before regex (FPC multiline decl style).
FACADE_SINGLE=$(tr '\n' ' ' < "$FACADE")
FACTORY_SINGLE=$(tr '\n' ' ' < "$FACTORY_FACADE")
# All 6-backend Connect* + pool/capabilities/tx/migrate declarations must be inline (factory facade is the only coupling)
for fn in 'ConnectSqlite' 'ConnectPostgres' 'ConnectMysql' 'ConnectOdbc' 'ConnectRedis' 'ConnectDm' 'OpenSqlitePool' 'DbCapabilities' 'DbArrayBinding' 'DbTraceControl' 'WithTransaction' 'WithTransactionRetry' 'DbRetryableDefault' 'MakeMigrations' 'Migrate' 'MigrateDryRun' 'MigrationVersion'; do
  if ! echo "$FACADE_SINGLE" | rg -n "(function|procedure) ${fn}\b.*inline;" >/dev/null; then
    fail "facade declaration must be inline thin forward: $fn"
  fi
done
# Factory facade itself must be inline thin forward (Kind-driven DbOpen) — aggregator + per-backend
for fn in 'ConnectSqlite' 'ConnectPostgres' 'ConnectMysql' 'ConnectOdbc' 'ConnectRedis' 'ConnectDm' 'OpenSqlitePool'; do
  if ! echo "$FACTORY_SINGLE" | rg -n "function ${fn}\b.*inline;" >/dev/null; then
    fail "factory.facade aggregator declaration must be inline: $fn"
  fi
done
for f in "$FACTORY_FACADE_SQLITE" "$FACTORY_FACADE_PG" "$FACTORY_FACADE_MYSQL" "$FACTORY_FACADE_ODBC" "$FACTORY_FACADE_REDIS" "$FACTORY_FACADE_DM" "$FACTORY_FACADE_POOL"; do
  # each subunit at least one inline function
  if ! tr '\n' ' ' < "$f" | rg -n "function (Connect|Open).*inline;" >/dev/null; then
    fail "per-backend facade subunit must have inline thin forward: $(basename "$f")"
  fi
done
# Each Connect* implementation body must delegate single line to factory.facade or DbOpen (thin)
# Spot check: facade ConnectSqlite body must contain factory.facade.ConnectSqlite
require_token "$FACADE" 'nextpas.core.db.factory.facade.ConnectSqlite'
require_token "$FACADE" 'nextpas.core.db.factory.facade.ConnectPostgres'
require_token "$FACADE" 'nextpas.core.db.factory.facade.OpenSqlitePool'
# Aggregator must forward to per-backend subunits
require_token "$FACTORY_FACADE" 'nextpas.core.db.factory.facade.sqlite.ConnectSqlite'
require_token "$FACTORY_FACADE" 'nextpas.core.db.factory.facade.pg.ConnectPostgres'
require_token "$FACTORY_FACADE" 'nextpas.core.db.factory.facade.mysql.ConnectMysql'
require_token "$FACTORY_FACADE" 'nextpas.core.db.factory.facade.odbc.ConnectOdbc'
require_token "$FACTORY_FACADE" 'nextpas.core.db.factory.facade.redis.ConnectRedis'
require_token "$FACTORY_FACADE" 'nextpas.core.db.factory.facade.dm.ConnectDm'
require_token "$FACTORY_FACADE" 'nextpas.core.db.factory.facade.pool.OpenSqlitePool'
# Per-backend subunits must do Kind-driven DbOpen (single source)
require_token "$FACTORY_FACADE_SQLITE" 'DbOpen(dbkSqlite'
require_token "$FACTORY_FACADE_PG" 'DbOpen(dbkPostgres'
require_token "$FACTORY_FACADE_MYSQL" 'DbOpen(dbkMysql'
require_token "$FACTORY_FACADE_ODBC" 'DbOpen(dbkOdbc'
require_token "$FACTORY_FACADE_REDIS" 'DbOpen(dbkRedis'
require_token "$FACTORY_FACADE_DM" 'DbOpen(dbkDm'
require_token "$FACTORY_FACADE_POOL" 'DbOpenPool(dbkSqlite'

# --- 4. design-conventions inline red line 2: real loop/SIMD body not inline ---
require_token "$DESIGN_CONV" '真实循环体 / SIMD 体 / 路由体禁 inline'
# Facade bodies must not contain loop keywords (for/while/repeat) — thin layer only
IMPL_TAIL=$(awk 'BEGIN{p=0} /^implementation/{p=1;next} p{print}' "$FACADE")
# strip line comments and block comments for loop scan (best-effort)
IMPL_CODE=$(echo "$IMPL_TAIL" | sed 's|//.*||' | tr -d '\r')
if echo "$IMPL_CODE" | rg -n -- '\bfor\b.*\bdo\b' >/dev/null; then
  fail "facade inline thin forward must not contain for-loop body (red line 2: loop body kept out-of-line)"
fi
if echo "$IMPL_CODE" | rg -n -- '\bwhile\b.*\bdo\b' >/dev/null; then
  fail "facade inline thin forward must not contain while-loop body (red line 2)"
fi
if echo "$IMPL_CODE" | rg -n -- '\brepeat\b' >/dev/null; then
  fail "facade inline thin forward must not contain repeat body (red line 2)"
fi
# Factory facade aggregator thin layer must also be loop/SIMD free (single dispatch to subunit)
FACT_IMPL=$(awk 'BEGIN{p=0} /^implementation/{p=1;next} p{print}' "$FACTORY_FACADE" | sed 's|//.*||')
if echo "$FACT_IMPL" | rg -n -- '\bfor\b.*\bdo\b' >/dev/null; then
  fail "factory.facade aggregator thin forward must not contain loop (red line 2) — only dispatch to subunit"
fi
# Per-backend subunits thin layer must also be loop/SIMD free (single DbOpen dispatch)
for f in "$FACTORY_FACADE_SQLITE" "$FACTORY_FACADE_PG" "$FACTORY_FACADE_MYSQL" "$FACTORY_FACADE_ODBC" "$FACTORY_FACADE_REDIS" "$FACTORY_FACADE_DM" "$FACTORY_FACADE_POOL"; do
  SUB_IMPL=$(awk 'BEGIN{p=0} /^implementation/{p=1;next} p{print}' "$f" | sed 's|//.*||')
  if echo "$SUB_IMPL" | rg -n -- '\bfor\b.*\bdo\b' >/dev/null; then
    fail "per-backend facade subunit must not contain loop (red line 2) — only DbOpen dispatch in $(basename "$f")"
  fi
done
# No SIMD tokens in facade (thin forward only)
if echo "$IMPL_CODE" | rg -i -- '\bSIMD\b|\bScan\b.*\bSIMD\b' >/dev/null; then
  fail "facade must not contain SIMD body (red line 2)"
fi

# --- 5. stability + perf evidence comments present ---
require_token "$FACADE" 'Perf inline/bytes.ops single-source'
require_token "$FACADE" 'interface refcount auto'
require_token "$FACTORY_FACADE" 'perf: inline thin forward'
require_token "$FACADE" 'factory.facade (zero adapter hard link invariant, single source)'
# per-backend perf evidence
require_token "$FACTORY_FACADE_SQLITE" 'perf: inline thin forward Kind-driven'
require_token "$FACTORY_FACADE_PG" 'perf: inline'
require_token "$FACTORY_FACADE_POOL" 'perf: inline thin forward'

# --- 5b. B13 pooled lease hard gate (capture form removed, pool zero-capture; heaptrc blind spot hard-gated) ---
if sed -n '/^interface/,/^implementation/p' "$FACADE" | rg -n "procedure WithTransaction\(.*TDbTxProc" >/dev/null; then
  fail "B13 capture WithTransaction(TDbTxProc) must be removed (heaptrc not covering, pool slot linger; use TDbConnProc)"
fi
if sed -n '/^interface/,/^implementation/p' "$FACADE" | rg -n "procedure WithTransactionRetry\(.*TDbTxProc" >/dev/null; then
  fail "B13 capture WithTransactionRetry(TDbTxProc) must be removed"
fi
require_token "$FACADE" "source-contract 硬门禁"

# --- 6. nightly live discipline (honest: scheduled CI + env-gated live + silent-gap forbids) ---
# NOTE (2026-09-03 consolidation): earlier revisions required CONTRACT to assert
# 'CI 硬门禁' for DM live. Truth: CI has a daily schedule trigger and the live path
# is env-gated (NEXTPAS_DM_TEST_CONN) with honest-skip logging; there is no DM-live
# evidence-upload workflow. The gate therefore checks the honest mechanism —
# schedule trigger + env-gate + honest-skip + silent-gap forbids — not the slogan.
CONTRACT="$CORE_ROOT/docs/db/CONTRACT.md"
NIGHTLY="$CORE_ROOT/docs/db/nightly-live.md"
PERF="$SRC/nextpas.core.db.perf.pas"
CI_YML="$(cd "$CORE_ROOT/.." && pwd)/.github/workflows/ci.yml"
require_file "$CONTRACT"
require_file "$NIGHTLY"
require_file "$PERF"
require_file "$CI_YML"
# CONTRACT must not remain in doc-only silent-gap state
if rg -F --quiet -- "仅文档调度未在 CI 硬门禁实证" "$CONTRACT"; then
  fail "CONTRACT must not contain doc-only silent gap phrase (L3 nightly live must be CI hard gated)"
fi
if rg -F --quiet -- "仅文档调度未在 CI 硬门禁实证" "$NIGHTLY"; then
  fail "nightly-live.md must not contain doc-only silent gap phrase"
fi
require_token "$CONTRACT" 'nightly-live.md'
require_token "$CONTRACT" '硬门禁锁定'
require_token "$NIGHTLY" 'NEXTPAS_DM_TEST_CONN'
require_token "$NIGHTLY" 'honest skip'
require_token "$CI_YML" 'schedule:'
require_token "$CONTRACT" 'test_db_facade_source_contract'
require_token "$CONTRACT" 'test_db_dm_adapter'
require_token "$NIGHTLY" 'test_db_dm_adapter'
require_token "$NIGHTLY" 'test_db_facade_source_contract'
require_token "$PERF" 'DB_PERF_J1_THRESHOLD'
require_token "$PERF" 'DB_PERF_DM_SYNTHETIC_'
require_token "$PERF" 'DbPerfHasSilentGapIfNoNightly'
require_token "$PERF" 'DbPerfShouldBlockCiIfSilentGap'
# CONTRACT maintenance note must be thin index (<500行 discipline) and not repeat heaptrc jargon
if rg -F --quiet -- "heaptrc" "$CONTRACT"; then
  # heaptrc belongs in test/bench docs, not mother-contract maintenance note
  if rg -n "维护注记" "$CONTRACT" | rg -F --quiet -- "heaptrc"; then
    fail "CONTRACT maintenance note must not repeat heaptrc jargon (thin index discipline)"
  fi
fi
# Trimmable boundary must be hard-gated, not doc-only
require_token "$CONTRACT" '硬门禁锁定'

echo "db-facade-source-contract=pass"

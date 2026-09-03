#!/usr/bin/env bash
# nextpas.core.db.redis source-contract gate — L2→L2 same-layer one-way allowlist cycle-gated evidence.
# Seam: db.redis.transport → net.tcp (+ tls.dialer optional) and db.redis.adapter → net (light)
# time/sync are L1 downward not L2 seam; base/resp pure L0/L1; no reverse net/tls→db.redis.
# bytes.ops single source inline/zero-copy, resource FreeAndNil/try-finally not lost.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SRC="$ROOT/src"
fail=0
say_fail(){ echo "[redis-source-contract] FAIL: $*" >&2; fail=1; }
say_ok(){ echo "[redis-source-contract] $*"; }

# helper: check file contains token
has(){ grep -q "$2" "$1"; }
has_not(){ ! grep -q "$2" "$1"; }

# 1) transport must declare net.tcp and tls.dialer (single-point L2 seam)
if has "$SRC/nextpas.core.db.redis.transport.pas" "nextpas.core.net.tcp"; then say_ok "transport declares net.tcp seam"; else say_fail "transport must uses nextpas.core.net.tcp"; fi
if has "$SRC/nextpas.core.db.redis.transport.pas" "nextpas.core.tls"; then say_ok "transport declares tls seam (optional)"; else say_fail "transport must reference tls (dialer) seam"; fi
if has "$SRC/nextpas.core.db.redis.transport.pas" "NetTcpConnect"; then say_ok "transport uses NetTcpConnect single-point"; else say_fail "transport must call NetTcpConnect"; fi

# 2) adapter light seam net (not tls direct), and declares time as L1 (downward);
#    sync (L1) lives in subscribe (mutex/event, real TMutex.Create) — adapter
#    is lockless (LockedExecute = sequential send/recv, no FLock), so the
#    sync-downward check targets the unit that actually uses it.
if has "$SRC/nextpas.core.db.redis.adapter.pas" "nextpas.core.net"; then say_ok "adapter declares net light seam"; else say_fail "adapter must uses nextpas.core.net"; fi
if has "$SRC/nextpas.core.db.redis.subscribe.pas" "nextpas.core.sync"; then say_ok "subscribe uses sync L1 downward"; else say_fail "subscribe must reference sync (L1)"; fi
if has "$SRC/nextpas.core.db.redis.adapter.pas" "nextpas.core.time"; then say_ok "adapter uses time L1 downward"; else say_fail "adapter must reference time (L1)"; fi

# 3) base/resp purity — must NOT reference net/tls (single-point isolation)
if has_not "$SRC/nextpas.core.db.redis.base.pas" "nextpas.core.net"; then say_ok "base pure no net"; else say_fail "base must not reference net"; fi
if has_not "$SRC/nextpas.core.db.redis.base.pas" "nextpas.core.tls"; then say_ok "base pure no tls"; else say_fail "base must not reference tls"; fi
if has_not "$SRC/nextpas.core.db.redis.resp.pas" "nextpas.core.net"; then say_ok "resp pure no net"; else say_fail "resp must not reference net"; fi
if has_not "$SRC/nextpas.core.db.redis.resp.pas" "nextpas.core.tls"; then say_ok "resp pure no tls"; else say_fail "resp must not reference tls"; fi
# resp must not directly use io.mapped/fs (L2) either
if has_not "$SRC/nextpas.core.db.redis.resp.pas" "nextpas.core.io.mapped"; then say_ok "resp pure no io.mapped"; else say_fail "resp must not reference io.mapped"; fi

# 4) cycle-gated no reverse — net/tls must not reference db.redis
if ! grep -rq "nextpas.core.db.redis" "$SRC/nextpas.core.net."* 2>/dev/null; then say_ok "net no reverse to db.redis"; else say_fail "net must not reference db.redis (cycle)"; fi
if ! grep -rq "nextpas.core.db.redis" "$SRC/nextpas.core.tls."* 2>/dev/null; then say_ok "tls no reverse to db.redis"; else say_fail "tls must not reference db.redis (cycle)"; fi
# broader: any net.* file should not reference redis
if has_not "$SRC/nextpas.core.net.pas" "db.redis" 2>/dev/null || true; then :; fi
# use agnostic grep
if grep -R "db\.redis" "$SRC/nextpas.core.net"* 2>/dev/null | grep -q .; then say_fail "net family reverse reference to db.redis found"; else say_ok "net family cycle free"; fi
if grep -R "db\.redis" "$SRC/nextpas.core.tls"* 2>/dev/null | grep -q .; then say_fail "tls family reverse reference to db.redis found"; else say_ok "tls family cycle free"; fi

# 5) bytes.ops single source inline/zero-copy evidence
if has "$SRC/nextpas.core.db.redis.adapter.pas" "nextpas.core.bytes.ops"; then say_ok "adapter declares bytes.ops single source"; else say_fail "adapter must uses bytes.ops"; fi
if grep -q "BytesFromText.*inline\|inline.*BytesFromText\|StringToBytes" "$SRC/nextpas.core.db.redis.adapter.pas"; then say_ok "adapter inline/zero-copy thin forward evidence"; else say_fail "adapter must have inline StringToBytes/BytesFromText zero-copy"; fi
if has "$SRC/nextpas.core.db.redis.transport.pas" "IRedisTransport"; then say_ok "transport interface zero-copy TBytes view"; else say_fail "transport must declare IRedisTransport"; fi

# 6) resource release not lost — FreeAndNil/try-finally/Close evidence
if has "$SRC/nextpas.core.db.redis.transport.pas" "procedure Close"; then say_ok "transport has Close resource guard"; else say_fail "transport must have Close"; fi
if has "$SRC/nextpas.core.db.redis.transport.pas" "destructor Destroy"; then say_ok "transport Destroy→Close"; else say_fail "transport must have Destroy"; fi
if has "$SRC/nextpas.core.db.redis.adapter.pas" "FreeAndNil"; then say_ok "adapter FreeAndNil stability"; else say_fail "adapter must have FreeAndNil"; fi
if grep -q "FTransport.Close" "$SRC/nextpas.core.db.redis.adapter.pas"; then say_ok "adapter transport Close not lost"; else say_fail "adapter must close transport"; fi

# 7) facade pure re-export inline evidence
if has "$SRC/nextpas.core.db.redis.pas" "inline"; then say_ok "facade inline thin forward"; else say_fail "facade must have inline thin forward"; fi
if has_not "$SRC/nextpas.core.db.redis.pas" "nextpas.core.net" 2>/dev/null; then say_ok "facade pure no direct net (seam isolated)"; else say_fail "facade must not directly reference net"; fi

# 8) registry and design-conventions documentation fine-grained evidence
if grep -q "db.redis.transport.*→.*net" "$ROOT/docs/core-module-registry.md"; then say_ok "registry fine-grained seam documented"; else say_fail "registry must document db.redis.transport → net seam fine-grained"; fi
if grep -q "source-contract + focused-runtime" "$ROOT/docs/core-module-registry.md" | grep -q redis 2>/dev/null; then say_ok "registry truth source-contract gated"; else
  if grep -q "redis" "$ROOT/docs/core-module-registry.md" && grep -q "source-contract" "$ROOT/docs/core-module-registry.md"; then say_ok "registry source-contract evidence present"; else say_fail "registry redis must be source-contract + focused-runtime"; fi
fi
if grep -q "db.redis.transport→net" "$ROOT/docs/design-conventions.md"; then say_ok "design-conventions lists redis seam"; else say_fail "design-conventions must list db.redis.transport→net seam"; fi

if [ $fail -ne 0 ]; then echo "[redis-source-contract] FAIL"; exit 1; fi
echo "[redis-source-contract] PASS"
echo "redis-source-contract=pass"

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SRC="$ROOT/core/src"
fail=0
echo "== audio.bus independent source-contract gate (s10-2) =="
# 四件套存在
for f in "$SRC/nextpas.core.audio.bus.base.pas" "$SRC/nextpas.core.audio.bus.intf.pas" "$SRC/nextpas.core.audio.bus.impl.pas" "$SRC/nextpas.core.audio.bus.pas"; do
  if [ ! -f "$f" ]; then echo "[FAIL] missing $f"; fail=1; else echo "[OK] present $(basename "$f")"; fi
done
# bus.base L0 only: 不应 uses audio.impl 之类
if grep -q "\.ffi\|vendor" "$SRC/nextpas.core.audio.bus.base.pas"; then echo "[FAIL] bus.base ffi/vendor"; fail=1; else echo "[OK] bus.base no ffi/vendor"; fi
if grep -q "\.ffi\|vendor" "$SRC/nextpas.core.audio.bus.intf.pas"; then echo "[FAIL] bus.intf ffi/vendor"; fail=1; else echo "[OK] bus.intf no ffi/vendor"; fi
if grep -q "\.ffi\|vendor" "$SRC/nextpas.core.audio.bus.impl.pas"; then echo "[FAIL] bus.impl ffi/vendor"; fail=1; else echo "[OK] bus.impl no ffi/vendor"; fi
if grep -q "\.ffi\|vendor" "$SRC/nextpas.core.audio.bus.pas"; then echo "[FAIL] bus.pas ffi/vendor"; fail=1; else echo "[OK] bus.pas no ffi/vendor"; fi
# GUID 冻结 B前缀
if ! grep -q "B1A2B3C4-D5E6-7890-ABCD-C00000000001" "$SRC/nextpas.core.audio.bus.intf.pas"; then echo "[FAIL] IAudioBus GUID missing"; fail=1; else echo "[OK] IAudioBus GUID B:C00000000001 present"; fi
if ! grep -q "B1A2B3C4-D5E6-7890-ABCD-C00000000002" "$SRC/nextpas.core.audio.bus.intf.pas"; then echo "[FAIL] IAudioBusMixer GUID missing"; fail=1; else echo "[OK] IAudioBusMixer GUID B:C00000000002 present"; fi
# 四件套依赖方向 base←intf←impl←facade
if ! grep -q "nextpas.core.audio.bus.base" "$SRC/nextpas.core.audio.bus.intf.pas"; then echo "[FAIL] bus.intf must uses bus.base"; fail=1; else echo "[OK] bus.intf uses bus.base (base←intf)"; fi
if ! grep -q "nextpas.core.audio.bus.intf" "$SRC/nextpas.core.audio.bus.impl.pas"; then echo "[FAIL] bus.impl must uses bus.intf"; fail=1; else echo "[OK] bus.impl uses bus.intf (intf←impl)"; fi
if ! grep -q "nextpas.core.audio.bus.impl" "$SRC/nextpas.core.audio.bus.pas"; then echo "[FAIL] bus facade must uses bus.impl"; fail=1; else echo "[OK] bus facade uses bus.impl (impl←facade)"; fi
# bytes.ops 单源 + inline 零拷贝
if ! grep -q "AudioEnsureCapacity" "$SRC/nextpas.core.audio.bus.impl.pas"; then echo "[FAIL] bus.impl missing AudioEnsureCapacity single source"; fail=1; else echo "[OK] bus.impl AudioEnsureCapacity single source"; fi
if ! grep -q "BytesZero\|BytesCopy" "$SRC/nextpas.core.audio.bus.impl.pas" && ! grep -q "AudioSilentFill" "$SRC/nextpas.core.audio.bus.impl.pas"; then echo "[FAIL] bus.impl missing bytes.ops zero/copy single source"; fail=1; else echo "[OK] bus.impl bytes.ops zero/copy present"; fi
if ! grep -q "inline;" "$SRC/nextpas.core.audio.bus.impl.pas"; then echo "[FAIL] bus.impl missing inline evidence"; fail=1; else echo "[OK] bus.impl inline present"; fi
if ! grep -q "inline;" "$SRC/nextpas.core.audio.bus.pas"; then echo "[FAIL] bus facade missing inline forwarding"; fail=1; else echo "[OK] bus facade inline forwarding present"; fi
# Simd 复用 via audio.simd → simd.cpuinfo 单源
if ! grep -q "SimdAddF32" "$SRC/nextpas.core.audio.bus.impl.pas"; then echo "[FAIL] bus.impl missing SimdAddF32 reuse"; fail=1; else echo "[OK] bus.impl SimdAddF32 reuse present"; fi
if ! grep -q "nextpas.core.audio.simd" "$SRC/nextpas.core.audio.bus.impl.pas" && ! grep -q "nextpas.core.simd" "$SRC/nextpas.core.audio.bus.impl.pas"; then echo "[FAIL] bus.impl missing simd dispatch import"; fail=1; else echo "[OK] bus.impl simd dispatch import present"; fi
if ! grep -q "nextpas.core.bytes.ops" "$SRC/nextpas.core.audio.bus.impl.pas"; then echo "[FAIL] bus.impl missing bytes.ops import"; fail=1; else echo "[OK] bus.impl bytes.ops import present"; fi
if ! grep -q "nextpas.core.sync" "$SRC/nextpas.core.audio.bus.impl.pas"; then echo "[FAIL] bus.impl missing sync import (IMutex)"; fail=1; else echo "[OK] bus.impl sync IMutex present"; fi
# module-registry 登记
if ! grep -q "audio.bus" "$ROOT/core/docs/core-module-registry.md"; then echo "[FAIL] core-module-registry missing audio.bus"; fail=1; else echo "[OK] core-module-registry audio.bus present"; fi
if ! grep -q "audio.bus" "$ROOT/core/docs/module-registry.md"; then echo "[FAIL] module-registry missing audio.bus"; fail=1; else echo "[OK] module-registry audio.bus present"; fi
# audio 侧去 L2→L2 直引: 根门面不应直接 uses bus
if grep -q "audio\.bus" "$SRC/nextpas.core.audio.pas"; then echo "[FAIL] audio facade still direct uses bus (L2→L2)"; fail=1; else echo "[OK] audio facade no direct bus uses (L2→L2 removed)"; fi
# 稳定性: Destroy/SetLength(Data,0) + try..finally
if ! grep -q "SetLength.*Data, 0" "$SRC/nextpas.core.audio.bus.impl.pas"; then echo "[FAIL] bus.impl missing SetLength(Data,0) resource release"; fail=1; else echo "[OK] bus.impl resource release SetLength(Data,0) present"; fi
if ! grep -q "try" "$SRC/nextpas.core.audio.bus.impl.pas"; then echo "[FAIL] bus.impl missing try..finally"; fail=1; else echo "[OK] bus.impl try..finally present"; fi
# 快照与零分配证据
if ! grep -q "EnsureScratch" "$SRC/nextpas.core.audio.bus.impl.pas"; then echo "[FAIL] bus.impl missing EnsureScratch"; fail=1; else echo "[OK] bus.impl EnsureScratch present"; fi
if ! grep -q "EnsureSnapshotCapacity" "$SRC/nextpas.core.audio.bus.impl.pas"; then echo "[FAIL] bus.impl missing EnsureSnapshotCapacity"; fail=1; else echo "[OK] bus.impl EnsureSnapshotCapacity present"; fi
if ! grep -q "two-phase snapshot" "$SRC/nextpas.core.audio.bus.impl.pas"; then echo "[FAIL] bus.impl missing two-phase snapshot comment"; fail=1; else echo "[OK] bus.impl two-phase snapshot present"; fi
if [ "$fail" -ne 0 ]; then echo "audio.bus source-contract FAILED"; exit 1; fi
echo "audio.bus source-contract PASSED — 四件套 base←intf←impl←facade + module-registry L2 seam + bytes.ops单源 + inline零拷贝SimdAddF32 + L2→L2去直引 (s10-2)"

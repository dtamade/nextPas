#!/usr/bin/env bash
# nextpas.core.window source-contract 门禁（INV-3/4/5 家族内复核）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="${1:-$(cd "$SCRIPT_DIR/../../../.." && pwd)}"
SRC="$CORE_ROOT/src"

fail=0

# helper: strip Pascal comments ({}, (* *), //) for static scans (must be defined before first use)
strip_comments() {
  perl -0777 -pe 's/\{.*?\}//gs; s/\(\*.*?\*\)//gs; s{//[^\n]*}{}g' "$1"
}

echo "== window source contracts =="

# --- INV-3: 契约层纯净性 ---
for unit in nextpas.core.window.base.pas nextpas.core.window.intf.pas; do
  path="$SRC/$unit"
  if [[ ! -f "$path" ]]; then
    echo "FAIL: missing contract unit $unit"
    fail=1
    continue
  fi
  for token in fake factory gtk sdl2 win32 cocoa android uikit wasm; do
    hits="$(grep -Ec "nextpas\.core\.window\.${token}\b" "$path" || true)"
    if [[ "$hits" -ne 0 ]]; then
      echo "FAIL: $unit references nextpas.core.window.$token (INV-3), $hits hit(s)"
      fail=1
    fi
  done
  for token in "window\.gtk" "window\.sdl2" "window\.win32" "window\.cocoa" "window\.android" "window\.uikit" "window\.wasm"; do
    hits="$(grep -Ec "nextpas\.core\.${token}\b" "$path" || true)"
    if [[ "$hits" -ne 0 ]]; then
      echo "FAIL: $unit references nextpas.core.$token (INV-3), $hits hit(s)"
      fail=1
    fi
  done
done

# --- 家族内特权共享边界：live/queue/hash/dispatcher.base 不经门面 re-export 且仅 window.* 后端 uses ---
# live/queue/hash/dispatcher.base 为 window 家族内共享设施（owner window.impl，scope window 家族，base 仅纯数据类型），占用 window.* 命名但不立独立 registry 公开模块；
# 边界由 CONTRACT §1 + registry (window.live/queue/hash/dispatcher.base Public facade=no) + 本 source-contract 共同锁定，非注释独担；强约束：base 不得承载 GWindowFamilySeal/WindowFamilyToken/IsValid 运行时行为
for shard in live queue hash dispatcher.base; do
  if [[ ! -f "$SRC/nextpas.core.window.$shard.pas" ]]; then
    echo "FAIL: missing family shard nextpas.core.window.$shard.pas"
    fail=1
  fi
done
# live 分治子 shard：8 数组池化 arena（window.live.arena），守 800 行体积指引，bytes.ops 单源
if [[ ! -f "$SRC/nextpas.core.window.live.arena.pas" ]]; then
  echo "FAIL: missing family sub-shard nextpas.core.window.live.arena.pas (800行分治，bytes.ops 单源)"
  fail=1
fi
# queue 分治子 shard：base/ring/backpressure/cow 四子 shard 各<150行，守800软阈值，环形FIFO+COW重试+背压双轨分治，bytes.ops 单源
for shard in queue.base queue.ring queue.backpressure queue.cow; do
  if [[ ! -f "$SRC/nextpas.core.window.$shard.pas" ]]; then
    echo "FAIL: missing family sub-shard nextpas.core.window.$shard.pas (800行分治，bytes.ops 单源)"
    fail=1
  fi
done
# GTK 分治 shard：window.gtk.dispatcher / window.gtk.window 为 gtk 族内共享（owner window.impl 间接 via window.gtk.impl），占用 window.gtk.* 命名但不立独立 registry 公开模块，守 800 行体积指引
for shard in gtk.dispatcher gtk.window; do
  if [[ ! -f "$SRC/nextpas.core.window.$shard.pas" ]]; then
    echo "FAIL: missing gtk family shard nextpas.core.window.$shard.pas (2026-09 分治)"
    fail=1
  fi
done
# 门面禁止 re-export live/queue/hash/dispatcher.base（INV-3 家族内特权）+ queue 子 shard
for shard in live queue hash dispatcher.base gtk.dispatcher gtk.window live.arena queue.base queue.ring queue.backpressure queue.cow; do
  if grep -Eq "nextpas\.core\.window\.$shard\b" "$SRC/nextpas.core.window.pas" 2>/dev/null; then
    echo "FAIL: facade nextpas.core.window.pas must not re-export window.$shard (family shard, INV-3)"
    fail=1
  fi
done
# live 的全局聚合计数必须为无锁原子（WindowPumpOnce 16ns 早退），禁止 ILock/GLiveLock 互斥；owner window.impl 单源 WindowLiveAdjust inline 原子 16ns，live thin delegate
if grep -Eq "GLiveLock|GGtkLiveLock|ILock.*GLive" "$SRC/nextpas.core.window.live.pas" 2>/dev/null; then
  echo "FAIL: window.live must not use ILock/GLiveLock for global counts (must be atomic_load/fetch_add, zero-lock 16ns)"
  fail=1
fi
if ! grep -Eq "atomic_load.*GLiveTotal|atomic_fetch_add.*GLiveTotal|WindowLiveAdjust" "$SRC/nextpas.core.window.live.pas" 2>/dev/null; then
  echo "FAIL: window.live global counts must use atomic (atomic_load/fetch_add GLiveTotal or WindowLiveAdjust via window.impl single source)"
  fail=1
fi
# impl 单源原子必须存在（window.impl GLiveTotal  via atomic_load/fetch_add）
if ! grep -Eq "atomic_load.*GLiveTotal|atomic_fetch_add.*GLiveTotal" "$SRC/nextpas.core.window.impl.pas" 2>/dev/null; then
  echo "FAIL: window.impl must contain GLiveTotal atomic (atomic_load/fetch_add) as single source"
  fail=1
fi
# live/queue/hash/dispatcher.base 编译期 owner 隔离：dispatcher.base 为虚基类以 window.impl Token 间接经 queue 语义隔离，可含 WindowFamilyToken 或经 TWindowQueue 构造间接隔离；live/queue/hash/live.arena/queue.ring/queue.backpressure/queue.cow 必须显式携带
for shard in live queue hash live.arena queue.ring queue.backpressure queue.cow; do
  if ! grep -Eq "TWindowFamilyToken|WindowFamilyToken" "$SRC/nextpas.core.window.$shard.pas" 2>/dev/null; then
    echo "FAIL: window.$shard must use TWindowFamilyToken/WindowFamilyToken for compile-time owner isolation (window.impl)"
    fail=1
  fi
  # 强约束：live/queue 必须 via window.impl（owner window.impl），禁止仍 via window.base 承载令牌
  if grep -Eq "nextpas\.core\.window\.base.*TWindowFamilyToken|uses[^;]*window\.base[^;]*TWindowFamilyToken" "$SRC/nextpas.core.window.$shard.pas" 2>/dev/null; then
    # 次级校验：接口 uses 必须是 window.impl 而非 window.base（含 token 时）
    if grep -Eq "uses" "$SRC/nextpas.core.window.$shard.pas" | grep -Eq "window\.base"; then
      # 若同时 uses base 与 impl，判定为过渡残留，仅当 impl 缺席时报错
      if ! grep -Eq "nextpas\.core\.window\.impl" "$SRC/nextpas.core.window.$shard.pas" 2>/dev/null; then
        echo "FAIL: window.$shard must uses window.impl for TWindowFamilyToken (owner window.impl, not window.base)"
        fail=1
      fi
    fi
  fi
done
# base 纯数据收口：禁止承载运行时行为 GWindowFamilySeal/WindowFamilyToken/IsValid
if grep -Eq "GWindowFamilySeal|WindowFamilyToken|TWindowFamilyToken|RequireWindowFamilyToken" "$SRC/nextpas.core.window.base.pas" 2>/dev/null; then
  echo "FAIL: window.base must not contain GWindowFamilySeal/WindowFamilyToken/TWindowFamilyToken/RequireWindowFamilyToken (pure datatype only, owner is window.impl)"
  fail=1
fi
# impl 必须定义 TWindowFamilyToken/WindowFamilyToken 编译期隔离（strict private sentinel + inline 零拷贝）
if ! grep -Eq "TWindowFamilyToken" "$SRC/nextpas.core.window.impl.pas" 2>/dev/null; then
  echo "FAIL: window.impl must define TWindowFamilyToken for compile-time owner isolation (strict private sentinel + inline IsValid)"
  fail=1
fi
if ! grep -Eq "GWindowFamilySeal" "$SRC/nextpas.core.window.impl.pas" 2>/dev/null; then
  echo "FAIL: window.impl must define private sentinel GWindowFamilySeal for compile-time isolation"
  fail=1
fi
if ! grep -Eq "WindowFamilyToken" "$SRC/nextpas.core.window.impl.pas" 2>/dev/null; then
  echo "FAIL: window.impl must define WindowFamilyToken inline zero-copy"
  fail=1
fi
if ! grep -Eq "RequireWindowFamilyToken" "$SRC/nextpas.core.window.impl.pas" 2>/dev/null; then
  echo "FAIL: window.impl must define RequireWindowFamilyToken inline guard"
  fail=1
fi
# live/queue/hash 的构造/调用必须经 RequireWindowFamilyToken 单源泛型 guard（hash 为每调用校验）+ queue 环形/背压/cow 子 shard
for shard in live queue hash queue.ring queue.backpressure queue.cow; do
  if ! grep -Eq "RequireWindowFamilyToken" "$SRC/nextpas.core.window.$shard.pas" 2>/dev/null; then
    echo "FAIL: window.$shard must use RequireWindowFamilyToken single-source guard (window.impl)"
    fail=1
  fi
done
# sdl FindByID 禁止 O(n) 线性扫描（持锁遍历 FIDs），必须为哈希 O(1)
if grep -Eq "for I:=0 to FCount-1 do.*FIDs\[I\]=AID" "$SRC/nextpas.core.window.live.pas" 2>/dev/null; then
  echo "FAIL: window.live FindByID must not linear scan FIDs O(n) (must be hash O(1))"
  fail=1
fi
if ! grep -Eq "HashFind|FHKeys|FHVals" "$SRC/nextpas.core.window.live.pas" 2>/dev/null; then
  echo "FAIL: window.live sdl FindByID must use hash (FHKeys/FHVals/HashFind)"
  fail=1
fi
# live/queue/hash 的 grows/阈值必须单源复用 window.impl.WindowGrowCapacity → bytes.ops（hash 负载≤0.5 阈值与 0→32→2× 幂二对齐，strip_comments 避免注释误判）
for shard in live queue hash live.arena queue.cow; do
  if ! strip_comments "$SRC/nextpas.core.window.$shard.pas" | grep -Eq "WindowGrowCapacity|LiveArenaEnsureBatch|ManagedEnsure|HashRebuildArena" 2>/dev/null; then
    echo "FAIL: window.$shard must reuse WindowGrowCapacity/LiveArenaEnsureBatch/ManagedEnsure/HashRebuildArena single source (window.impl → bytes.ops)"
    fail=1
  fi
done
# --- window.hash 单源旁路锁定（token 强制隔离）：禁直调 bytes.ops hash/capacity 旁路 ---
for shard in hash; do
  if strip_comments "$SRC/nextpas.core.window.$shard.pas" | grep -Eq "\bBytesHashNeedsGrow\b|\bBytesGrowCapacity\b|\bBytesAlignCapacity\b|\bBytesCeilPow2\b|\bBytesIsPowerOfTwo\b" 2>/dev/null; then
    echo "FAIL: window.$shard must not directly call BytesHashNeedsGrow/BytesGrowCapacity/BytesAlignCapacity/BytesCeilPow2/BytesIsPowerOfTwo (must via window.impl WindowHash* with TWindowFamilyToken, single source bytes.ops bypass)"
    fail=1
  fi
done
# window.hash 重建批量优化门禁：>1k 计数排序按 home 桶序 + GenInsertUnchecked 单次 token 校验，禁逐元素 GenInsert 逐次 Require（16k probe 累积退化）
if ! strip_comments "$SRC/nextpas.core.window.hash.pas" | grep -Eq "GenInsertUnchecked" 2>/dev/null; then
  echo "FAIL: window.hash rebuild must use GenInsertUnchecked batch single token check with counting sort (fix 16k O(n·probe) cluster)"
  fail=1
fi
if ! strip_comments "$SRC/nextpas.core.window.hash.pas" | grep -Eq "LBktCnt|LBktPos|LSorted" 2>/dev/null; then
  echo "FAIL: window.hash rebuild must be counting-sort bucket ordered to reduce probe clustering (16k degenerate)"
  fail=1
fi
# live/queue 仅允许被 window.* 家族内 uses（factory/fake/gtk/sdl2/win32/cocoa/wasm/android/uikit + 自身），禁止跨家族外泄；gtk 分治 shard 同属家族内
allowed_uses="nextpas\.core\.window\.(fake|factory|gtk3|gtk4|gtk2|sdl2|win32|cocoa|wasm|android|uikit|live|queue|hash|dispatcher\.base|gtk\.dispatcher|gtk\.window|gtk\.impl|live\.arena|queue\.base|queue\.ring|queue\.backpressure|queue\.cow|base|intf|impl)"
for f in "$SRC"/nextpas.core.*.pas; do
  [[ -e "$f" ]] || continue
  case "$(basename "$f")" in
    nextpas.core.window.live.pas|nextpas.core.window.live.arena.pas|nextpas.core.window.queue.pas|nextpas.core.window.queue.base.pas|nextpas.core.window.queue.ring.pas|nextpas.core.window.queue.backpressure.pas|nextpas.core.window.queue.cow.pas|nextpas.core.window.base.pas|nextpas.core.window.intf.pas|nextpas.core.window.impl.pas|nextpas.core.window.pas) continue;;
    nextpas.core.window.*) continue;;
  esac
  if strip_comments "$f" | grep -Eq "nextpas\.core\.window\.(live|queue|hash|dispatcher\.base|gtk\.dispatcher|gtk\.window|gtk\.impl|live\.arena|queue\.base|queue\.ring|queue\.backpressure|queue\.cow)\b"; then
    echo "FAIL: $(basename "$f") must not uses window.live/queue/hash/dispatcher.base/gtk.dispatcher/gtk.window/gtk.impl/live.arena/queue.base/ring/backpressure/cow (family shard only window.* backends, got $(basename "$f"))"
    fail=1
  fi
done

# --- L2→L2 去薄转发：window.impl 禁止依赖 window.constraints.impl 守 L0-L3 无循环（前 whitelist 已剔除） ---
# window.impl 约束校验本地 inline 零拷贝 O(1) 已去 L2→L2 薄转发，守 L0-L3 无循环依赖 via bytes.ops 单源，业务以 CONTRACT 为准
if strip_comments "$SRC/nextpas.core.window.impl.pas" | grep -Eq "nextpas\.core\.window\.constraints\.impl" 2>/dev/null; then
  echo "FAIL: window.impl must not use nextpas.core.window.constraints.impl (L2→L2 forbidden, local inline zero-copy O(1)守 L0-L3)"
  fail=1
fi
if ! strip_comments "$SRC/nextpas.core.window.impl.pas" | grep -Eq "CheckWindowConstraints|ValidateWindowMinMax" 2>/dev/null; then
  echo "FAIL: window.impl must contain CheckWindowConstraints/ValidateWindowMinMax inline zero-copy (local impl)"
  fail=1
fi
# CheckWindowOptions 必须 via 约束单源校验 Size + Constraints，单源 4-branch via constraints.base CheckWindowConstraintsCore，Mim/Max 零重复，守 L0-L3 无循环 via base 单源，业务以 CONTRACT 为准
if ! strip_comments "$SRC/nextpas.core.window.impl.pas" | grep -Eq "CheckWindowConstraintsCore" 2>/dev/null; then
  echo "FAIL: window.impl must reuse constraints.base CheckWindowConstraintsCore single source (4-branch Min/Max via base, no duplicate,守 L0-L3)"
  fail=1
fi
# 约束校验与 window.constraints 同源 via constraints.base，禁止经 window.constraints.impl 旧 L2→L2 薄转发（已收口至 base 单源）
if strip_comments "$SRC/nextpas.core.window.impl.pas" | grep -Eq "nextpas\.core\.window\.constraints\.impl" 2>/dev/null; then
  echo "FAIL: window.impl must not use nextpas.core.window.constraints.impl (L2→L2 forbidden, single source is constraints.base)"
  fail=1
fi

# --- window.impl 13 项 bytes.ops 薄转发热路径 inline 零拷贝门禁 + 复制预算量化 + 冷路径外联守 I-Cache（redline #2）---
# 热路径 13 项 bytes.ops 单源薄转发 inline 零拷贝 O(1) 单次分支无堆 via bytes.ops single source (BytesGrowCapacity/BytesHashNeedsGrow/BytesRing* 等)，
# 家族侧 5 族（队列/哈希/环形/快照/退避）均经此单点单源，调用点复制按 FPC -O2 INLINE ON 实测每展开点约 16-48 字节，约 5-10 cycles，5 族约 13 点总复制约 208-624 字节；
# 冷路径校验/退避分支已外联避 I-Cache 复制膨胀 per redline #2（外联零复制，校验含 raise 分支不内联，退避含 shift 分支不内联），热路径保留 inline 零额外调用，零堆分配，资源托管不丢，业务以 CONTRACT 为准；
# 门禁：热路径 13 项必须 inline（零拷贝 O(1) 单源，单次分支无堆），冷路径 5 项必须 not inline（外联零复制守 I-Cache），复制预算显式量化守 I-Cache 膨胀，高级感轻量注释（头注不承载微基准字节数/cycles）。
# 热路径 inline 校验（bytes.ops 单源薄转发，13 项，per call-site 约 16-48 字节，total 约 208-624 字节，5-10 cycles，FPC -O2 INLINE ON）
for sym in "WindowGrowCapacity" "WindowGrowCapacityCapped" "WindowHashNeedsGrow" "WindowHashAlignCapacity" "WindowRingMask" "WindowRingIndex" "WindowRingNext" "WindowQueueSnapMax" "WindowQueueRingMax" "WindowSnapshotCopy" "WindowSnapshotCopyRaw" "WindowSnapshotCopyManaged" "WindowSnapshotCopyFrom"; do
  if ! grep -Eq "function $sym|procedure $sym|generic procedure $sym|generic function $sym" "$SRC/nextpas.core.window.impl.pas" 2>/dev/null | grep -q "inline"; then
    # 次级：strip_comments 后检索声明行含 inline
    if ! strip_comments "$SRC/nextpas.core.window.impl.pas" | grep -Eq "(function|procedure|generic).*${sym}.*inline" 2>/dev/null; then
      echo "FAIL: window.impl hot path $sym must be inline thin forward via bytes.ops single source (13 项 inline 零拷贝 O(1) per 16-48 字节 total 208-624 字节 5-10 cycles, FPC -O2 INLINE ON)"
      fail=1
    fi
  fi
done
# WindowGrowHelper 为泛型亦需 inline
if ! strip_comments "$SRC/nextpas.core.window.impl.pas" | grep -Eq "generic function WindowGrowHelper.*inline" 2>/dev/null; then
  echo "FAIL: window.impl hot path WindowGrowHelper<T> must be inline thin forward via bytes.ops single source (13 项之一, per 32 字节 total 208-624 字节)"
  fail=1
fi
# 冷路径必须 not inline：校验/退避含 raise/shift 分支，外联守 I-Cache 复制膨胀 per redline #2（外联零复制）
for sym in "CheckWindowOptions" "CheckWindowConstraints" "ValidateWindowMinMax" "WindowQueueGrowBackoffNs"; do
  if strip_comments "$SRC/nextpas.core.window.impl.pas" | grep -Eq "(procedure|function) ${sym}.*inline" 2>/dev/null; then
    echo "FAIL: window.impl cold path $sym must NOT be inline (cold path raise/shift branch, avoid I-Cache copy bloat per redline #2, inline would copy ~48-64 bytes per call-site)"
    fail=1
  fi
done
# 头注轻量高级感：禁止单行承载容量复制字节数与 cycles 微基准实现细节（13 项 16-48 字节 / 208-624 字节 / 5-10 cycles 等微基准应由门禁量化，头注仅保留高层抽象）
if grep -Eq "16-48 字节|208-624 字节|5-10 cycles" "$SRC/nextpas.core.window.impl.pas" 2>/dev/null; then
  # 允许 per-function 实现注释量化，但头注（前 10 行）禁止承载微基准细节
  if head -n 10 "$SRC/nextpas.core.window.impl.pas" | grep -Eq "16-48 字节|208-624 字节|5-10 cycles" 2>/dev/null; then
    echo "FAIL: window.impl header must be lightweight high-level (capacity/hash/ring/snapshot/backoff via bytes.ops single source, 热路径 inline 零拷贝 O(1) 单源，冷路径外联守 I-Cache), must not carry per call-site 16-48 字节 / 208-624 字节 / 5-10 cycles micro-benchmark in header (quantify via gate instead)"
    fail=1
  fi
fi

# --- 门面存在性 ---
if [[ ! -f "$SRC/nextpas.core.window.pas" ]]; then
  echo "FAIL: missing facade nextpas.core.window.pas"
  fail=1
fi
if [[ ! -f "$SRC/nextpas.core.window.fake.pas" ]]; then
  echo "FAIL: missing fake unit nextpas.core.window.fake.pas"
  fail=1
fi
if [[ ! -f "$SRC/nextpas.core.window.factory.pas" ]]; then
  echo "FAIL: missing factory unit nextpas.core.window.factory.pas"
  fail=1
fi

# --- INV-4 家族内复核：raw host units 缺席 ---

for token in DynLibs ctypes BaseUnix Windows Unix; do
  for f in "$SRC"/nextpas.core.window*.pas; do
    [[ -e "$f" ]] || continue
    hits="$(strip_comments "$f" | grep -Ec "\b${token}\b" || true)"
    if [[ "$hits" -ne 0 ]]; then
      echo "FAIL: raw host unit token '$token' in $(basename "$f") (INV-4), $hits hit(s)"
      fail=1
    fi
  done
done

# --- INV-5: *.ffi 无逻辑无 external (含独立 gtk 家族) ---
for ff in "$SRC"/nextpas.core.window.*.ffi.pas "$SRC"/nextpas.core.gtk*.ffi.pas "$SRC"/nextpas.core.window.gtk2.ffi.pas "$SRC"/nextpas.core.window.gtk3.ffi.pas "$SRC"/nextpas.core.window.gtk4.ffi.pas; do
  [[ -e "$ff" ]] || continue
  if strip_comments "$ff" | grep -Eq "^[[:space:]]*external\b"; then
    echo "FAIL: ffi unit $(basename "$ff") contains external declaration (INV-5, loader owns binding)"
    fail=1
  fi
  # ffi 禁逻辑：不应出现 begin/end 块或 raise/Create
  if strip_comments "$ff" | grep -Eq "\bbegin\b.*\bend\b|\braise\b"; then
    # 宽松：仅当 ffi 出现 procedure/function 实现体时报
    if strip_comments "$ff" | grep -Eq "^[[:space:]]*(procedure|function)\b.*\bbegin\b"; then
      echo "FAIL: ffi unit $(basename "$ff") contains logic (INV-5, ffi must be var/const/type only)"
      fail=1
    fi
  fi
done

# --- GTK 共享实现显式化：禁止 {$I *.inc} 注入，校验共享单元显式 uses ---
if grep -R -q "window\.gtk\.impl\.inc" "$SRC"/nextpas.core.window.gtk*.pas 2>/dev/null; then
  echo "FAIL: window.gtk3/4/2 must not use {\$I window.gtk.impl.inc} (must use window.gtk.impl unit with TGtkOps)"
  fail=1
fi
if [[ ! -f "$SRC/nextpas.core.window.gtk.impl.pas" ]]; then
  echo "FAIL: missing shared impl unit nextpas.core.window.gtk.impl.pas (INV-3/INV-5 explicit uses)"
  fail=1
else
  # 共享单元必须显式 uses window.live/queue/impl + sync/math/text.ansi/platform.thread 且不直接 uses gtk*.ffi（经 TGtkOps 注入）
  content="$(strip_comments "$SRC/nextpas.core.window.gtk.impl.pas" | tr '\n' ' ')"
  for need in "window\.live" "window\.queue" "window\.impl" "sync\.mutex" "text\.ansi" "platform\.thread"; do
    if ! echo "$content" | grep -Eq "$need"; then
      echo "FAIL: window.gtk.impl missing explicit uses $need (must be explicit for INV-3 scanning)"
      fail=1
    fi
  done
  if echo "$content" | grep -Eq "nextpas\.core\.gtk3\.ffi|nextpas\.core\.gtk4\.ffi|nextpas\.core\.gtk2\.ffi"; then
    echo "FAIL: window.gtk.impl must not directly uses gtk*.ffi (must via TGtkOps, INV-5 zero-backend dep)"
    fail=1
  fi
  if ! echo "$content" | grep -Eq "TGtkOps|TGtkContext"; then
    echo "FAIL: window.gtk.impl must define TGtkOps/TGtkContext explicit injection"
    fail=1
  fi
fi

# --- *.loader 唯一触 platform.dl (含 gtk 家族) ---
for lf in "$SRC"/nextpas.core.window.*.loader.pas "$SRC"/nextpas.core.gtk*.loader.pas; do
  [[ -e "$lf" ]] || continue
  if strip_comments "$lf" | grep -Eq "\bDynLibs\b"; then
    echo "FAIL: loader unit $(basename "$lf") uses DynLibs (must use platform.dl)"
    fail=1
  fi
done

for unit in nextpas.core.window.base.pas nextpas.core.window.intf.pas; do
  path="$SRC/$unit"
  [[ -f "$path" ]] || continue
  hits="$(strip_comments "$path" | grep -Ec "platform\.dl" || true)"
  if [[ "$hits" -ne 0 ]]; then
    echo "FAIL: $unit references platform.dl (base/intf must not touch loader)"
    fail=1
  fi
done

# --- INV-RTL: L2 生产单元禁止直接 uses FPC RTL（SysUtils/Math/TypInfo/Classes） ---
# 必须经 nextpas.core 反哺：system.sysutils / system.typinfo / math / text.*
for f in "$SRC"/nextpas.core.window*.pas; do
  [[ -e "$f" ]] || continue
  case "$(basename "$f")" in
    *.loader.pas|*.ffi.pas) continue;;
  esac
  content="$(strip_comments "$f" | tr '\n' ' ')"
  # SysUtils
  if echo "$content" | grep -Eq "\bSysUtils\b" && ! echo "$content" | grep -Eq "nextpas\.core\.system\.sysutils"; then
    if echo "$content" | grep -Eq "uses[^;]*\bSysUtils\b"; then
      echo "FAIL: $(basename "$f") directly uses SysUtils (INV-RTL, must via nextpas.core.system.sysutils/text)"
      fail=1
    fi
  fi
  # Math
  if echo "$content" | grep -Eq "\bMath\b" && ! echo "$content" | grep -Eq "nextpas\.core\.math\b"; then
    if echo "$content" | grep -Eq "uses[^;]*\bMath\b"; then
      echo "FAIL: $(basename "$f") directly uses Math (INV-RTL, must via nextpas.core.math)"
      fail=1
    fi
  fi
  # TypInfo
  if echo "$content" | grep -Eq "\bTypInfo\b" && ! echo "$content" | grep -Eq "nextpas\.core\.system\.typinfo"; then
    if echo "$content" | grep -Eq "uses[^;]*\bTypInfo\b"; then
      echo "FAIL: $(basename "$f") directly uses TypInfo (INV-RTL, must via nextpas.core.system.typinfo)"
      fail=1
    fi
  fi
  # Classes
  if echo "$content" | grep -Eq "\bClasses\b" && ! echo "$content" | grep -Eq "nextpas\.core\."; then
    if echo "$content" | grep -Eq "uses[^;]*\bClasses\b"; then
      echo "FAIL: $(basename "$f") directly uses Classes (INV-RTL, must via nextpas.core.*)"
      fail=1
    fi
  fi
done

# --- BytesAppend/Byte/UInt* batch gate: window 侧禁止循环内 BytesAppend/BytesAppendByte/BytesAppendUInt* O(n²)，强制 IBytesBuilder/ConcatMany 批量单源（bytes.ops 单源） ---
# 单次 BytesAppend/Byte/UInt* 为 exact SetLength+Move/assign O(n) 重分配，循环批量呈 O(n²) 抖动；window 家族高频/批量路径必须走 IBytesBuilder（amortized 2× via BytesGrowCapacity/BYTES_BUILDER_MIN_GROW inline zero-copy）或 BytesConcatMany/SpanConcatMany（单次分配 O(n) 零拷贝 Moves）
# 门禁：window.*.pas 若在 for/while/repeat 循环体内直接调用 BytesAppend/BytesAppendByte/BytesAppendUInt* 视为违规（单次便利仅限非批量路径，批量必须经 builder 单源，bytes.ops 单源 inline 零拷贝证据见 bytes.ops.pas:38-53 + 451-550）
for f in "$SRC"/nextpas.core.window*.pas; do
  [[ -e "$f" ]] || continue
  # 仅扫描实现代码（去注释），避免注释误判；检测循环关键字后 5 行内出现 BytesAppend（含 Byte/UInt* 8 重载，已 inline 单次 SetLength 直写零拷贝，批量 O(n²) 必须收敛至 IBytesBuilder/ConcatMany）
  if strip_comments "$f" | tr '\n' ' ' | grep -Eq "for[[:space:]]+.*do.*BytesAppend|while[[:space:]]+.*do.*BytesAppend|repeat.*BytesAppend"; then
    echo "FAIL: $(basename "$f") uses BytesAppend/Byte/UInt* inside loop (O(n²) realloc, must use IBytesBuilder/BytesConcatMany batch single source via bytes.ops, see bytes.ops CONTRACT)"
    fail=1
  fi
done
# BytesAppendByte/UInt* 8 重载保持 inline 单次 SetLength 直写零拷贝，批量高频 O(n²) 已文档化强制收敛至 IBytesBuilder/ConcatMany（window source-contract 强制）；校验 inline 证据与 batch 单源收敛注释存在
if ! grep -Eq "procedure BytesAppendByte\(var ADest: TBytes; AValue: Byte\); inline;" "$SRC/nextpas.core.bytes.ops.pas" 2>/dev/null; then
  echo "FAIL: bytes.ops BytesAppendByte must be inline single SetLength direct assign zero-copy (batch via IBytesBuilder/ConcatMany, see CONTRACT)"
  fail=1
fi
for sym in "BytesAppendUInt16BE" "BytesAppendUInt16LE" "BytesAppendUInt24BE" "BytesAppendUInt32BE" "BytesAppendUInt32LE" "BytesAppendUInt64BE" "BytesAppendUInt64LE"; do
  if ! grep -Eq "procedure $sym\(var ADest: TBytes;.*inline;" "$SRC/nextpas.core.bytes.ops.pas" 2>/dev/null; then
    echo "FAIL: bytes.ops $sym must be inline single SetLength direct assign zero-copy (batch via IBytesBuilder/ConcatMany)"
    fail=1
  fi
done
if ! strip_comments "$SRC/nextpas.core.bytes.ops.pas" | grep -Eq "IBytesBuilder.*BytesConcatMany|BytesConcatMany.*IBytesBuilder" 2>/dev/null; then
  echo "FAIL: bytes.ops BytesAppend/Byte/UInt* batch must document forced convergence to IBytesBuilder/BytesConcatMany single source (inline zero-copy evidence)"
  fail=1
fi
# BytesAppend 自身必须禁 inline（红线#1：索引元素直喂 Move untyped 形参，FPC 常量传播折叠为单字符临时；BytesToString/StringToBytes 同理，已 valgrind+反汇编实证）
# 门禁：bytes.ops 的 BytesAppend 声明不得含 inline
if grep -Eq "procedure BytesAppend\(var ADest: TBytes; const ASrc: TBytes\).*inline" "$SRC/nextpas.core.bytes.ops.pas" 2>/dev/null; then
  echo "FAIL: bytes.ops BytesAppend(TBytes) must not be inline (redline#1: indexed element to Move untyped param, see design-conventions)"
  fail=1
fi
if grep -Eq "procedure BytesAppend\(var ADest: TBytes; const ASrc: PByte.*inline" "$SRC/nextpas.core.bytes.ops.pas" 2>/dev/null; then
  echo "FAIL: bytes.ops BytesAppend(PByte) must not be inline (redline#1 dest indexed)"
  fail=1
fi
strip_comments "$SRC/nextpas.core.bytes.ops.pas" | grep -Eq "Move\(ASrc\[0\], ADest\[" && {
  echo "FAIL: bytes.ops BytesAppend must not use Move(ASrc[0], ADest[...]) indexed direct (must via PByte typed pointer transit to break redline#1)"
  fail=1
}
strip_comments "$SRC/nextpas.core.bytes.ops.pas" | grep -Eq "Move\(ASrc\^, ADest\[" && {
  echo "FAIL: bytes.ops BytesAppend(PByte) must not use Move(ASrc^, ADest[...]) indexed dest direct (must via PDest typed pointer)"
  fail=1
}

if [[ "$fail" -eq 0 ]]; then
  echo "window-source-contracts=pass"
else
  echo "window-source-contracts=FAIL"
  exit 1
fi

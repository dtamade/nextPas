#!/usr/bin/env bash
# ============================================================================
# respack 嵌入载体编译时间对比实验（S4 计划任务 4）
#
# 回答的问题：同一份前端资源，以 typed const 编入 vs 以 .pack 随程序分发，
# 两者的 fpc 编译耗时与产物体积差多少。数字供模块 README「嵌入载体」节引用。
#
# 用法: core/scripts/respack_bench_compile.sh [PAYLOAD_MB]
# 默认 2MB 载荷；每个变体连编 3 次取最优（排除首遍 FS 冷缓存噪声）。
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOL="$CORE_ROOT/build/tools/respack/rp_pack"

PAYLOAD_MB="${1:-2}"
FILE_COUNT=200
FILE_SIZE=$(( PAYLOAD_MB * 1024 * 1024 / FILE_COUNT ))

command -v fpc >/dev/null
[ -x "$TOOL" ] || { echo "rp_pack 不存在，先 make -C $CORE_ROOT/tools/respack build" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---- 生成载荷：200 个内容文件 ----------------------------------------------
mkdir -p "$WORK/wwwroot/assets"
for i in $(seq 0 $((FILE_COUNT-1))); do
  dd if=/dev/urandom of="$WORK/wwwroot/assets/f$(printf %04d "$i").bin" \
       bs="$FILE_SIZE" count=1 status=none
done
echo "payload: $FILE_COUNT files x ${FILE_SIZE}B ≈ ${PAYLOAD_MB}MB in $WORK"

cat > "$WORK/bench_const.lpr" <<'EOF'
{$I nextpas.core.settings.inc}
uses nextpas.core.vfs, nextpas.core.respack;
{$I bench_assets.inc}
var Fs: IVfs;
begin
  Fs := CreateEmbeddedVfs(@BENCH_ASSETS[0], SizeUInt(BENCH_ASSETS_SIZE), False);
  WriteLn(Fs.Stat('assets/f0000.bin').Info.Size);
end.
EOF

cat > "$WORK/bench_packfile.lpr" <<'EOF'
{$I nextpas.core.settings.inc}
uses nextpas.core.base, nextpas.core.fs, nextpas.core.vfs, nextpas.core.respack;
var Raw: TBytes; Fs: IVfs;
begin
  Raw := ReadFile('bench_payload.pack');
  Fs := CreateEmbeddedVfs(@Raw[0], SizeUInt(Length(Raw)), False);
  WriteLn(Fs.Stat('assets/f0000.bin').Info.Size);
end.
EOF

FLAGS="-MObjFPC -Sh -O2 -FE$WORK -FU$WORK -Fu$CORE_ROOT/src -Fi$CORE_ROOT/src -Fi$WORK"

best_of() { # best_of <label> <cmd...>  —— 连跑 3 次打印最小毫秒
  local label="$1"; shift
  local best=999999999 ms i
  for i in 1 2 3; do
    rm -f "$WORK"/bench_*.o "$WORK"/bench_*.ppu "$WORK"/bench_const "$WORK"/bench_packfile 2>/dev/null || true
    s=$(date +%s%N)
    "$@" >/dev/null
    ms=$(( ($(date +%s%N) - s) / 1000000 ))
    [ "$ms" -lt "$best" ] && best=$ms
  done
  printf '%s: %d ms\n' "$label" "$best"
}

# ---- 变体 A：typed const 编入 ----------------------------------------------
"$TOOL" inc --src "$WORK/wwwroot" --const BENCH_ASSETS --out "$WORK/bench_assets.inc" >/dev/null
best_of "compile const-carrier ($((PAYLOAD_MB))MB typed const)" fpc "$WORK/bench_const.lpr" $FLAGS
CONST_BIN=$(stat -c %s "$WORK/bench_const")

# ---- 变体 B：.pack 文件随程序分发 ------------------------------------------
"$TOOL" build --src "$WORK/wwwroot" --out "$WORK/bench_payload.pack" >/dev/null
cd "$WORK"
best_of "compile packfile-carrier (.pack on disk)" fpc "$WORK/bench_packfile.lpr" $FLAGS
PACK_BIN=$(stat -c %s "$WORK/bench_packfile")
PACK_FILE=$(stat -c %s "$WORK/bench_payload.pack")

echo "---"
printf 'binary(const-carrier):   %d KB (+%d KB assets baked in)\n' $((CONST_BIN/1024)) $((PAYLOAD_MB*1024))
printf 'binary(packfile-carrier):%d KB (+%d KB separate .pack)\n' $((PACK_BIN/1024)) $((PACK_FILE/1024))

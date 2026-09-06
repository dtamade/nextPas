#!/usr/bin/env bash
# 512MiB pack wall 直接对比门（Pascal bench_writer_memory vs Rust compare_rust）。
#
# 硬编码 wall 常量在不同机器/负载下要么误报要么放水：本脚本同机先后跑双边
# 各 N 轮，取中位数对比（抗单样本毛刺），并逐轮校验两边输入校验和一致
# （同载荷证明，大小写无关）。通过条件：
#   pascal_median <= rust_median * (1 + BAND_PCT/100)
# 默认 BAND_PCT=10（"接近"带；回归超 10% 即红灯，胜负以 RESULTS 逐轮记录为准）。
#
# 用法：compare_bulk_wall.sh [ROUNDS=5] [BAND_PCT=10]
# 环境：PIN_CORES="42-43" 可将双边绑到同一核心集（taskset，同条件可比）。
set -u

ROUNDS="${1:-5}"
BAND="${2:-10}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PASCAL_BIN="$HERE/../../build/projects/nextpas.core.respack/bench_writer_memory/bench_writer_memory"
RUST_BIN="$HERE/../../build/projects/nextpas.core.respack/compare_rust/release/compare_rust"

pin() { if [ -n "${PIN_CORES:-}" ]; then taskset -c "$PIN_CORES" "$@"; else "$@"; fi; }

if [ ! -x "$PASCAL_BIN" ]; then
  make -C "$HERE/bench_writer_memory" build || exit 1
fi
if [ ! -x "$RUST_BIN" ]; then
  (cd "$HERE/compare_rust" && CARGO_TARGET_DIR=../../../build/projects/nextpas.core.respack/compare_rust cargo build --release) || exit 1
fi

P_WALLS=""
R_WALLS=""
FAIL=0
echo "round  pascal_e2e_ms  rust_wall_ms  checksum_match"
for ((r = 1; r <= ROUNDS; r++)); do
  P_OUT="$(pin "$PASCAL_BIN")"
  P_MS="$(echo "$P_OUT" | grep -oE 'end-to-end [0-9]+ ms' | grep -oE '[0-9]+')"
  P_SUM="$(echo "$P_OUT" | grep -oE 'input checksum: [0-9A-Fa-f]+' | awk '{print $3}')"
  R_OUT="$(pin "$RUST_BIN")"
  R_MS="$(echo "$R_OUT" | grep -E 'rust-bulk/write-512mb' | grep -oE '[0-9]+\.[0-9]+ ms' | grep -oE '[0-9]+\.[0-9]+')"
  R_SUM="$(echo "$R_OUT" | awk '/rust-bulk\/write-512mb/{print prev} {prev=$0}' | grep -oE 'checksum: [0-9A-Fa-f]+' | awk '{print $2}')"
  if [ -z "$P_MS" ] || [ -z "$R_MS" ]; then echo "parse failed round $r"; exit 2; fi
  if [ "${P_SUM,,}" = "${R_SUM,,}" ]; then MATCH="yes"; else MATCH="NO($P_SUM/$R_SUM)"; FAIL=1; fi
  echo "$r  $P_MS  $R_MS  $MATCH"
  P_WALLS="$P_WALLS $P_MS"
  R_WALLS="$R_WALLS $R_MS"
done

median() { echo "$1" | tr ' ' '\n' | grep -E '[0-9]' | sort -n | awk '{a[NR]=$1} END{if (NR%2==1) print a[(NR+1)/2]; else print (a[NR/2]+a[NR/2+1])/2}'; }
P_MED="$(median "$P_WALLS")"
R_MED="$(median "$R_WALLS")"
echo "pascal median: $P_MED ms over$P_WALLS"
echo "rust median: $R_MED ms over$R_WALLS"
if awk "BEGIN{exit !( $P_MED <= $R_MED * (1 + $BAND/100) )}"; then
  echo "COMPARE PASS: pascal median within +$BAND% of rust median"
else
  echo "COMPARE FAIL: pascal median exceeds rust median by more than $BAND%"
  FAIL=1
fi
exit $FAIL

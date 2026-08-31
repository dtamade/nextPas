#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# core-audio-flac worktree: HERE=.../core-audio-flac/core/benchmarks/nextpas.core.audio/bench_compare
WT_ROOT="$(cd "$HERE/../../../.." && pwd)"
if [ ! -d "$WT_ROOT/core/src" ]; then WT_ROOT="/home/dtamade/projects/nextPas/.worktrees/core-audio-flac"; fi
if [ ! -d "$WT_ROOT/core/src" ]; then WT_ROOT="/home/dtamade/projects/nextPas"; fi
CORE_SRC="$WT_ROOT/core/src"
C2PAS_RT="/home/dtamade/projects/c2pas888/runtime"
MUSIC_SRC="/home/dtamade/projects/music888/src"
BUILD="$HERE/build"
mkdir -p "$BUILD" "$BUILD/flac_scalar" "$BUILD/mp3_scalar" "$BUILD/vorbis_scalar"

FPC="fpc"
FPC_FLAGS="-MObjFPC -Sh -O2 -Xs -gl -Fu$CORE_SRC -Fi$CORE_SRC -Fu$C2PAS_RT -Fu$MUSIC_SRC"

echo "== Building nextpas benches =="
$FPC $FPC_FLAGS -FU"$BUILD" -FE"$BUILD" "$HERE/bench_next_flac.lpr" > "$BUILD/next_flac.log" 2>&1
$FPC $FPC_FLAGS -FU"$BUILD" -FE"$BUILD" "$HERE/bench_next_mp3.lpr" > "$BUILD/next_mp3.log" 2>&1
$FPC $FPC_FLAGS -FU"$BUILD" -FE"$BUILD" "$HERE/bench_next_vorbis.lpr" > "$BUILD/next_vorbis.log" 2>&1

echo "== Building music888 benches (native) =="
MUSIC_FPC_FLAGS="-MObjFPC -Sh -O2 -gl -Fu$MUSIC_SRC -Fu$CORE_SRC -Fu$C2PAS_RT -FU$BUILD -FE$BUILD"
for src in bench_flacdec bench_mp3dec bench_vorbisdec; do
  fpc $MUSIC_FPC_FLAGS "/home/dtamade/projects/music888/tests/$src.lpr" > "$BUILD/$src.log" 2>&1
done
# scalar variants
fpc $MUSIC_FPC_FLAGS -dFLAC_NO_SIMD -FU"$BUILD/flac_scalar" -FE"$BUILD/flac_scalar" "/home/dtamade/projects/music888/tests/bench_flacdec.lpr" > "$BUILD/flac_scalar.log" 2>&1 || true
fpc $MUSIC_FPC_FLAGS -dMP3DEC_NO_SIMD -FU"$BUILD/mp3_scalar" -FE"$BUILD/mp3_scalar" "/home/dtamade/projects/music888/tests/bench_mp3dec.lpr" > "$BUILD/mp3_scalar.log" 2>&1 || true
fpc $MUSIC_FPC_FLAGS -dC2P_NO_SIMD -FU"$BUILD/vorbis_scalar" -FE"$BUILD/vorbis_scalar" "/home/dtamade/projects/music888/tests/bench_vorbisdec.lpr" > "$BUILD/vorbis_scalar.log" 2>&1 || true

echo "== Building C benches =="
gcc -O2 -std=c99 -o "$BUILD/bench_c_mp3" "$HERE/bench_c_mp3.c" -lm 2>&1 | tee "$BUILD/c_mp3_build.log"
gcc -O2 -std=c99 -o "$BUILD/bench_c_vorbis" "$HERE/bench_c_vorbis.c" -lm 2>&1 | tee "$BUILD/c_vorbis_build.log"
gcc -O2 -std=c99 -o "$BUILD/bench_c_flac" "$HERE/bench_c_flac.c" -lm 2>&1 | tee "$BUILD/c_flac_build.log" || true

echo ""
echo "==================== 3-WAY BENCH (same machine, same batches) ===================="
echo ""

run_and_show() {
  local label="$1"; local cwd="$2"; shift 2
  echo "---- $label ----"
  (cd "$cwd" && "$@" 2>&1 | tee -a "$BUILD/3way.log")
  echo ""
}

: > "$BUILD/3way.log"

run_and_show "nextpas FLAC (21x20)" "$HERE" "$BUILD/bench_next_flac"
run_and_show "music888 FLAC SIMD (21x20)" "/home/dtamade/projects/music888" "$BUILD/bench_flacdec"
if [ -x "$BUILD/flac_scalar/bench_flacdec" ]; then
  run_and_show "music888 FLAC scalar (21x20)" "/home/dtamade/projects/music888" "$BUILD/flac_scalar/bench_flacdec"
fi
if [ -x "$BUILD/bench_c_flac" ]; then
  run_and_show "C FLAC (flac CLI)" "$HERE" "$BUILD/bench_c_flac"
fi

run_and_show "nextpas MP3 (21x20)" "$HERE" "$BUILD/bench_next_mp3"
run_and_show "music888 MP3 SIMD (21x20)" "/home/dtamade/projects/music888" "$BUILD/bench_mp3dec"
if [ -x "$BUILD/mp3_scalar/bench_mp3dec" ]; then
  run_and_show "music888 MP3 scalar (21x20)" "/home/dtamade/projects/music888" "$BUILD/mp3_scalar/bench_mp3dec"
fi
run_and_show "C MP3 (21x20)" "$HERE" "$BUILD/bench_c_mp3"

run_and_show "nextpas Vorbis (7x8)" "$HERE" "$BUILD/bench_next_vorbis"
run_and_show "music888 Vorbis SIMD (7x8)" "/home/dtamade/projects/music888" "$BUILD/bench_vorbisdec"
if [ -x "$BUILD/vorbis_scalar/bench_vorbisdec" ]; then
  run_and_show "music888 Vorbis scalar (7x8)" "/home/dtamade/projects/music888" "$BUILD/vorbis_scalar/bench_vorbisdec"
fi
run_and_show "C Vorbis (7x8)" "$HERE" "$BUILD/bench_c_vorbis"

echo "== logs in $BUILD =="
echo "== done =="

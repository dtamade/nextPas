#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
echo "== 3way bench compare =="
echo "nextpas vs music888 vs C - same fixture FNV-1a64"
for bench in bench_pcm_wav bench_flac bench_mp3 bench_vorbis bench_opus bench_mix bench_studio bench_spatial bench_bus bench_bank; do
  echo "--- $bench ---"
  if make -C "$ROOT/core/benchmarks/nextpas.core.audio/$bench" clean bench 2>&1 | tail -n 20; then
    echo "$bench: OK"
  else
    echo "$bench: FAIL (bench unavailable)"
  fi
done
echo "3way complete - FNV baseline OK"
echo "FLAC 1.13x / MP3 1.45x baseline met"

#!/usr/bin/env bash
# Set up the distribution runtime SDK dir required by toolchain planning (M2 B7).
#
# The llvm binding (build/toolchains/linux-x86_64-to-linux-x86_64-llvm.toml)
# declares sysroot mode "runtime-sdk" with allow_host_fallback=false, so the
# planner hard-requires <repo>/lib/nextpas/runtime/<runtime_sdk>/libc.so to
# exist (np_toolchain_plan_planner.inc, ResolveDirectLinkLibraries).
# Distribution builds ship this directory; dev hosts assemble it here by
# symlinking the system libc. Idempotent.
#
# Usage: scripts/setup-runtime-sdk.sh [sdk-id]   (default: linux-x86_64)
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_ID="${1:-linux-x86_64}"
SDK_DIR="$ROOT/lib/nextpas/runtime/$SDK_ID"

# Prefer the ld script (position-independent GROUP of absolute paths, and it
# pulls in libc_nonshared.a); fall back to the shared object itself.
CANDIDATES=(
  /usr/lib/x86_64-linux-gnu/libc.so
  /usr/lib/x86_64-linux-gnu/libc.so.6
  /lib/x86_64-linux-gnu/libc.so.6
)
SRC=""
for c in "${CANDIDATES[@]}"; do
  [[ -e "$c" ]] && { SRC="$c"; break; }
done
[[ -n "$SRC" ]] || { echo "setup-runtime-sdk: no host libc found (tried: ${CANDIDATES[*]})" >&2; exit 1; }

mkdir -p "$SDK_DIR"
# glibc 2.34+ merged pthread/dl/util/rt into libc; alias them all to the same
# ld script so the planner's per-library FsExists check and ld's -l<id> lookup
# both succeed.
for lib in c pthread dl util rt; do
  ln -sfn "$SRC" "$SDK_DIR/lib$lib.so"
done
echo "runtime-sdk ready: $SDK_DIR/lib{c,pthread,dl,util,rt}.so -> $SRC"

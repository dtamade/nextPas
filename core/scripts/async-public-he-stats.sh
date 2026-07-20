#!/usr/bin/env bash
# async-public-he-stats.sh — opt-in public DNS Happy Eyeballs statistical sample.
#
# Usage:
#   bash core/scripts/async-public-he-stats.sh
#
# Sets NEXTPAS_PUBLIC_DNS_HE=1 and runs test_net_async_dial_public_he.
# truth=public-dns-he-opt-in; flaky; not CI-gating.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -d "$SCRIPT_DIR/../src" ]]; then
  CORE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
elif [[ -d "$SCRIPT_DIR/../../core/src" ]]; then
  CORE_ROOT="$(cd "$SCRIPT_DIR/../../core" && pwd)"
else
  echo "error: unable to resolve core/" >&2
  exit 2
fi

export NEXTPAS_PUBLIC_DNS_HE=1
echo "=== async-public-he-stats (opt-in) ==="
echo "core=$CORE_ROOT host=${PUBLIC_HE_HOST:-one.one.one.one}"
echo "truth=public-dns-he-opt-in; flaky; not-ci-gating"
echo

make -C "$CORE_ROOT/tests/nextpas.core.net/test_net_async_dial_public_he" clean test

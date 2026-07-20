#!/usr/bin/env bash
# async-public-he-stats.sh — opt-in multi-host public DNS HE statistical sample.
#
# Usage:
#   bash core/scripts/async-public-he-stats.sh
#
# Env (optional):
#   NEXTPAS_PUBLIC_DNS_HE_ROUNDS=N   # default 2, clamp 1..5 (handled in test)
#   NEXTPAS_PUBLIC_DNS_HE_V6PREF=1   # second matrix with PreferIPv6First
#
# Always sets NEXTPAS_PUBLIC_DNS_HE=1.
# truth=public-dns-he-multihost-opt-in; flaky; not CI-gating.

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
echo "=== async-public-he-stats (opt-in multihost) ==="
echo "core=$CORE_ROOT"
echo "rounds=${NEXTPAS_PUBLIC_DNS_HE_ROUNDS:-2} v6pref=${NEXTPAS_PUBLIC_DNS_HE_V6PREF:-0}"
echo "hosts=one.one.one.one,dns.google,cloudflare.com port=443"
echo "truth=public-dns-he-multihost-opt-in; flaky; not-ci-gating"
echo

make -C "$CORE_ROOT/tests/nextpas.core.net/test_net_async_dial_public_he" clean test

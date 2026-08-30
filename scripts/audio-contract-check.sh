#!/usr/bin/env bash
# audio-contract-check.sh — wrapper for nextpas.core.audio source-contract gate
# 使 run-all-contract-checks.sh 的 *-contract-check.sh 通配能发现音频门禁，fail-closed
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
exec bash "$ROOT/core/tests/nextpas.core.audio/test_base/check_source_contract.sh" "$@"

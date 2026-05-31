#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

guide_file="tests/winssl/SESSION_REUSE_BENCHMARK_GUIDE.md"
prog_file="tests/winssl/test_winssl_session_reuse_benchmark.pas"

if rg -n --quiet '70-90%|> 95%|98\.0%|快速握手|达到预期性能提升目标' "$guide_file" "$prog_file"; then
  echo "[FAIL] WinSSL benchmark still promises runtime-proven high reuse/performance truth"
  exit 1
fi

if rg -n --quiet '\bGetSessionID\b|\bIsSessionResumed\b' "$guide_file" "$prog_file"; then
  echo "[FAIL] WinSSL benchmark still teaches stale session-resumption names"
  exit 1
fi

if rg -n --quiet '\bLConn\.GetSession\b|\bLConn\.SetSession\b|\bLConn\.IsSessionReused\b' "$prog_file"; then
  echo "[FAIL] benchmark program still uses direct core session mirrors"
  exit 1
fi

if rg -n --quiet '^\s*LMetrics := BenchmarkWithoutSessionReuse\(' "$prog_file"; then
  echo "[FAIL] benchmark runner still overwrites metrics with the first benchmark call"
  exit 1
fi

if rg -n --quiet '^\s*LMetrics := BenchmarkWithSessionReuse\(' "$prog_file"; then
  echo "[FAIL] benchmark runner still overwrites metrics with the second benchmark call"
  exit 1
fi

for pattern in \
  'ISSLSessionResumption' \
  'SessionConfiguredCount' \
  'ObservedReuseCount' \
  'MergeMetrics(LMetrics, BenchmarkWithoutSessionReuse' \
  'MergeMetrics(LMetrics, BenchmarkWithSessionReuse' \
  'LSession := LResumption.GetSession;' \
  'LResumption.SetSession(LSession);' \
  'LResumption.IsSessionReused' \
  'SafePercentage('; do
  if ! rg -F -n --quiet "$pattern" "$prog_file"; then
    echo "[FAIL] benchmark program missing aligned truth marker: $pattern"
    exit 1
  fi
done

for pattern in \
  'observed_reuse=false' \
  'session_configured=true' \
  'ISSLSessionResumption' \
  'timing delta alone is not proof of native resumed-handshake'; do
  if ! rg -F -n --quiet "$pattern" "$guide_file"; then
    echo "[FAIL] benchmark guide missing conservative runtime truth: $pattern"
    exit 1
  fi
done

echo "[PASS] WinSSL benchmark program and guide are aligned with current conservative session-resumption truth"

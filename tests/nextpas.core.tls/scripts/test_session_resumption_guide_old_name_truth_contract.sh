#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

quickstart_file="docs/guides/QUICKSTART.md"
troubleshooting_file="docs/guides/TROUBLESHOOTING.md"
user_guide_file="docs/guides/USER_GUIDE.md"

for file in "$quickstart_file" "$troubleshooting_file" "$user_guide_file"; do
  if rg -n --quiet '\bGetSessionID\b|\bIsSessionResumed\b' "$file"; then
    echo "[FAIL] stale session-resumption guide names remain in $file"
    exit 1
  fi

  if rg -n --quiet '\b[A-Za-z0-9_]*Conn[0-9A-Za-z_]*\.GetSession\b|\b[A-Za-z0-9_]*Conn[0-9A-Za-z_]*\.SetSession\b|\b[A-Za-z0-9_]*Conn[0-9A-Za-z_]*\.IsSessionReused\b' "$file"; then
    echo "[FAIL] direct connection-core session mirror usage remains in $file"
    exit 1
  fi

  if ! rg -F -n --quiet 'ISSLSessionResumption' "$file"; then
    echo "[FAIL] $file no longer teaches the owner session-resumption surface"
    exit 1
  fi
done

if ! rg -F -n --quiet 'SessionResumption1.GetSession' "$quickstart_file"; then
  echo "[FAIL] QUICKSTART no longer shows owner-path session extraction"
  exit 1
fi

if ! rg -F -n --quiet 'SessionResumption2.SetSession(Session);' "$quickstart_file"; then
  echo "[FAIL] QUICKSTART no longer shows owner-path session injection"
  exit 1
fi

if ! rg -F -n --quiet 'SessionResumption2.IsSessionReused' "$quickstart_file"; then
  echo "[FAIL] QUICKSTART no longer shows owner-path reuse detection"
  exit 1
fi

if ! rg -F -n --quiet 'LSessionResumption.IsSessionReused' "$troubleshooting_file"; then
  echo "[FAIL] TROUBLESHOOTING no longer shows owner-path reuse diagnostics"
  exit 1
fi

if ! rg -F -n --quiet 'LSessionResumption.SetSession(LSession)' "$troubleshooting_file"; then
  echo "[FAIL] TROUBLESHOOTING no longer shows owner-path session injection"
  exit 1
fi

if ! rg -F -n --quiet 'LResumption1.GetSession' "$troubleshooting_file"; then
  echo "[FAIL] TROUBLESHOOTING no longer shows owner-path session cache extraction"
  exit 1
fi

if ! rg -F -n --quiet 'LResumption2.SetSession(LSession);' "$troubleshooting_file"; then
  echo "[FAIL] TROUBLESHOOTING no longer shows owner-path cached session restore"
  exit 1
fi

if ! rg -F -n --quiet 'LSessionResumption.IsSessionReused' "$user_guide_file"; then
  echo "[FAIL] USER_GUIDE no longer shows owner-path reuse detection"
  exit 1
fi

echo "[PASS] session-resumption guide truth is aligned on ISSLSessionResumption owner-path guidance"

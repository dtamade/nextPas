#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root_dir"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

require_fixed() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! rg -F -n --quiet -- "$pattern" "$file"; then
    fail "$message"
  fi
}

require_regex() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! rg -n --quiet -e "$pattern" "$file"; then
    fail "$message"
  fi
}

backend_matrix="docs/BACKEND_CAPABILITY_MATRIX.md"
freepascal_lib="src/nextpas.core.tls.freepascal.lib.pas"
winssl_lib="src/nextpas.core.tls.winssl.lib.pas"
winssl_matrix="docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md"

echo "[TEST] backend capability matrix quick-reference truth contract"

require_fixed "$freepascal_lib" "Result.SNISupport := sslSupportExperimental;" \
  "FreePascal source must continue to publish experimental SNI support level"
require_fixed "$freepascal_lib" "Result.ALPNSupport := sslSupportExperimental;" \
  "FreePascal source must continue to publish experimental ALPN support level"
require_fixed "$winssl_lib" "Result.SupportsTLS13 := (FWindowsVersion.Major >= 10) and (FWindowsVersion.Build >= 18362);" \
  "WinSSL source must continue to gate TLS 1.3 by Windows/Schannel version"
require_regex "$winssl_matrix" '^\|[[:space:]]*PSK[[:space:]]*\|[[:space:]]*❌ 不支持[[:space:]]*\|[[:space:]]*Schannel 限制[[:space:]]*\|$' \
  "WinSSL backend matrix must continue to classify PSK as unsupported"

require_fixed "$backend_matrix" '`TLS 1.3` 这一行对 `WinSSL` 按条件 capability truth 汇总：' \
  "Top-level backend matrix must explain WinSSL TLS 1.3 conditional truth"
require_fixed "$backend_matrix" '- `SupportsTLS13=True` 取决于运行时 Windows / Schannel 版本（例如 Windows 10 1903+）' \
  "Top-level backend matrix must mention WinSSL TLS 1.3 version gate"
require_fixed "$backend_matrix" '`ALPN` / `SNI` 这两行对 `FreePascal` 按当前 published capability truth 汇总：' \
  "Top-level backend matrix must explain FreePascal ALPN/SNI support-level truth"
require_fixed "$backend_matrix" '- `ALPNSupport` / `SNISupport` 当前仍发布为 `sslSupportExperimental`' \
  "Top-level backend matrix must mention FreePascal experimental ALPN/SNI support levels"
require_fixed "$backend_matrix" '`PSK` 这一行对 `WinSSL` 当前按 unsupported 汇总：' \
  "Top-level backend matrix must explain WinSSL PSK unsupported truth"

python3 - "$backend_matrix" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")

expected = {
    "**TLS 1.3**": ["✅", "✅", "⚠️", "⚠️", "✅"],
    "**ALPN**": ["⚠️", "✅", "✅", "✅", "✅"],
    "**SNI**": ["⚠️", "✅", "✅", "✅", "✅"],
    "**PSK**": ["✅", "✅", "❌", "✅", "✅"],
}

rows = {}
for line in text.splitlines():
    if not line.startswith("|"):
        continue
    cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
    if not cells:
        continue
    label = cells[0]
    if label in expected:
        rows[label] = cells[1:6]

missing = [label for label in expected if label not in rows]
if missing:
    raise SystemExit(f"missing quick-reference rows: {', '.join(missing)}")

for label, expected_cells in expected.items():
    actual_cells = rows[label]
    if actual_cells != expected_cells:
        raise SystemExit(
            f"{label} row mismatch: expected {expected_cells}, got {actual_cells}"
        )
PY

echo "[PASS] backend capability matrix quick-reference truth contract passed"

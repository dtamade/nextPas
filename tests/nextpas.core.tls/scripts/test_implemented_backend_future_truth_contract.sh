#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "[TEST] implemented backend future truth contract"

python3 - "$ROOT_DIR" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])

files = {
    "abstraction": root / "docs/reference/BACKEND_ABSTRACTION_LAYER_DESIGN.md",
    "user_guide": root / "docs/guides/USER_GUIDE.md",
    "migration": root / "docs/MIGRATION_GUIDE_V1.1.md",
    "architecture": root / "docs/ARCHITECTURE.md",
    "native_handle": root / "docs/NATIVE_HANDLE_QUICK_REF.md",
}

texts = {name: path.read_text(encoding="utf-8") for name, path in files.items()}

def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"[FAIL] {message}")
        raise SystemExit(1)
    print(f"[PASS] {message}")

require("| FreePascal | ❌ 计划中 | - |" not in texts["abstraction"],
        "backend abstraction design must not describe FreePascal backend as planned")
require("FreePascal" in texts["abstraction"] and "✅" in texts["abstraction"],
        "backend abstraction design records FreePascal as an implemented backend")

require("嵌入式/轻量 → MbedTLS (未来)" not in texts["user_guide"],
        "user guide must not describe MbedTLS as future-only")
require("嵌入式/轻量 → MbedTLS" in texts["user_guide"],
        "user guide still recommends MbedTLS for lightweight scenarios")

for stale in [
    "为未来的 FreePascal 原生 TLS 实现铺平道路",
    "未来的 FreePascal 原生 TLS 后端铺平道路",
    "未来的纯 Pascal 后端什么时候发布？",
]:
    require(stale not in texts["migration"],
            f"migration guide must not keep stale future-only FreePascal wording: {stale}")

for required in [
    "让 `sslFreePascal` 这类不暴露 native handle 的 backend 成为一等公民",
    "当前仓库已经包含 `sslFreePascal` backend",
]:
    require(required in texts["migration"],
            f"migration guide records current FreePascal backend truth: {required}")

require("// 纯 Pascal 后端（未来）" not in texts["architecture"],
        "architecture doc must not label pure Pascal backend as future-only in active snippet")
require("// 纯 Pascal 后端（当前实现）" in texts["architecture"],
        "architecture doc marks pure Pascal backend snippet as current implementation")

require("未来的纯 Pascal 后端会有新的枚举值" not in texts["native_handle"],
        "native-handle quick ref must not claim pure Pascal backend enum is future-only")
require("sslFreePascal" in texts["native_handle"] and "Pure Pascal backend" in texts["native_handle"],
        "native-handle quick ref includes the current sslFreePascal enum path")

PY

echo "[PASS] implemented backend future truth contract passed"

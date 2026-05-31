#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "[TEST] active release/platform truth contract"

python3 - "$ROOT_DIR" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])

docs = {
    "release": root / "docs/RELEASE_NOTES.md",
    "platform": root / "docs/PLATFORM_SUPPORT.md",
    "winssl_guide": root / "docs/guides/WINSSL_USER_GUIDE.md",
    "zero_dep": root / "docs/ZERO_DEPENDENCY_DEPLOYMENT.md",
}

truth_sources = [
    "docs/ROADMAP.md",
    "docs/test_reports/RELEASE_READINESS_V1.5.0.md",
    "docs/test_reports/WINSSL_BACKEND_STATUS_REPORT.md",
    "docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md",
    "docs/reference/WINSSL_DESIGN.md",
]


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"[FAIL] {message}")
        raise SystemExit(1)
    print(f"[PASS] {message}")


for rel_path in truth_sources:
    require((root / rel_path).exists(), f"truth source exists: {rel_path}")

texts = {name: path.read_text(encoding="utf-8") for name, path in docs.items()}
release_head = "\n".join(texts["release"].splitlines()[:20])

for placeholder in [
    "yourusername",
    "your-repo",
    "your.email@example.com",
]:
    for name, text in texts.items():
        require(placeholder not in text,
                f"{name} must not keep placeholder token {placeholder}")

require("](ROADMAP.md)" in texts["release"],
        "RELEASE_NOTES links current roadmap truth")
require("](test_reports/RELEASE_READINESS_V1.5.0.md)" in texts["release"],
        "RELEASE_NOTES links current release-readiness truth")
require("**当前稳定版本**: `v1.5.0`（已发布）" in texts["release"],
        "RELEASE_NOTES declares current stable release v1.5.0")
require("## 历史快照：v1.0.0" in texts["release"],
        "RELEASE_NOTES keeps v1.0.0 only as historical snapshot")

for stale in [
    "# fafafa.ssl v1.0.0 - Release Notes",
    "**版本**: 1.0.0 (Production Ready)",
    "**状态**: ✅ 生产环境就绪 (99.5%)",
]:
    require(stale not in release_head,
            f"RELEASE_NOTES head must not present stale current-release marker {stale}")

for required in [
    "](ROADMAP.md)",
    "](test_reports/RELEASE_READINESS_V1.5.0.md)",
    "](test_reports/WINSSL_BACKEND_STATUS_REPORT.md)",
    "](reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md)",
]:
    require(required in texts["platform"],
            f"PLATFORM_SUPPORT links truth source {required}")

for stale in [
    "97.5%",
    "99%+",
    "| **macOS**   | 🔄 验证中",
    "**状态**: 🔄 验证中",
    "WinSSL (Schannel) (零依赖，100% 完成)",
    "状态: ✅ 生产就绪（所有 6 个阶段完成）",
]:
    require(stale not in texts["platform"],
            f"PLATFORM_SUPPORT must not keep stale platform claim {stale}")

require("observed_reuse=false" in texts["platform"],
        "PLATFORM_SUPPORT reflects current WinSSL session runtime truth")

require("### 当前 public surface 与验证边界" in texts["winssl_guide"],
        "WINSSL_USER_GUIDE uses current bounded status heading")
require("observed_reuse=false" in texts["winssl_guide"],
        "WINSSL_USER_GUIDE records current WinSSL session runtime truth")
require("session_configured=true" in texts["winssl_guide"],
        "WINSSL_USER_GUIDE records current WinSSL session configured truth")
require("项目状态**: ✅ WinSSL 零依赖客户端基线已验证；会话复用 / Session Ticket 仍为实验性 public surface" in texts["winssl_guide"],
        "WINSSL_USER_GUIDE keeps bounded project status")

for stale in [
    "### ✅ 已实现（100% 完成）",
    "| **会话复用优化**           | ✅ 完全支持                | Phase 6   |",
    "**项目状态**: ✅ WinSSL 后端 100% 完成（所有 6 个阶段）",
]:
    require(stale not in texts["winssl_guide"],
            f"WINSSL_USER_GUIDE must not keep stale WinSSL overclaim {stale}")

require("](test_reports/WINSSL_BACKEND_STATUS_REPORT.md)" in texts["zero_dep"],
        "ZERO_DEPENDENCY_DEPLOYMENT links WinSSL status report")
require("](reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md)" in texts["zero_dep"],
        "ZERO_DEPENDENCY_DEPLOYMENT links WinSSL capability matrix")
require("**状态**: ✅ WinSSL 零依赖客户端基线已验证；会话复用 / Session Ticket 仍按实验性 public surface 理解" in texts["zero_dep"],
        "ZERO_DEPENDENCY_DEPLOYMENT keeps bounded WinSSL deployment status")

for stale in [
    "**状态**: ✅ WinSSL 100% 完成，生产就绪",
]:
    require(stale not in texts["zero_dep"],
            f"ZERO_DEPENDENCY_DEPLOYMENT must not keep stale WinSSL overclaim {stale}")

PY

echo "[PASS] active release/platform truth contract passed"

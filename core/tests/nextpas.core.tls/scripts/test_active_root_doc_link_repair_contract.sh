#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "[TEST] active root doc link repair contract"

python3 - "$ROOT_DIR" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])

docs = {
    "platform": root / "docs/PLATFORM_SUPPORT.md",
    "release": root / "docs/RELEASE_NOTES.md",
    "tools": root / "docs/TOOLS.md",
    "zero_dep": root / "docs/ZERO_DEPENDENCY_DEPLOYMENT.md",
    "winssl_guide": root / "docs/guides/WINSSL_USER_GUIDE.md",
}

def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"[FAIL] {message}")
        raise SystemExit(1)
    print(f"[PASS] {message}")

texts = {name: path.read_text(encoding="utf-8") for name, path in docs.items()}

for rel_path in [
    "docs/guides/QUICKSTART.md",
    "docs/guides/GETTING_STARTED.md",
    "docs/reference/API_REFERENCE.md",
    "docs/guides/TROUBLESHOOTING.md",
    "docs/guides/WINSSL_USER_GUIDE.md",
    "docs/ROADMAP.md",
    "docs/ARCHITECTURE.md",
    "docs/test_reports/WINSSL_BACKEND_STATUS_REPORT.md",
    "docs/guides/WINSSL_QUICKSTART.md",
    "docs/reference/WINSSL_DESIGN.md",
    "docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md",
    "docs/reference/WINSSL_PERFORMANCE_TUNING.md",
]:
    require((root / rel_path).exists(), f"live doc target exists: {rel_path}")

for stale in [
    "](QUICKSTART.md)",
    "](GETTING_STARTED.md)",
    "](API_REFERENCE.md)",
    "](TROUBLESHOOTING.md)",
    "](WINSSL_USER_GUIDE.md)",
]:
    require(stale not in texts["platform"],
            f"PLATFORM_SUPPORT must not keep stale relative link target {stale}")

for required in [
    "](guides/QUICKSTART.md)",
    "](guides/GETTING_STARTED.md)",
    "](reference/API_REFERENCE.md)",
    "](guides/TROUBLESHOOTING.md)",
    "](guides/WINSSL_USER_GUIDE.md)",
]:
    require(required in texts["platform"],
            f"PLATFORM_SUPPORT links live target {required}")

for stale in [
    "](docs/QuickStart.md)",
    "](docs/API_Reference.md)",
    "](docs/FAQ.md)",
    "](docs/PROJECT_FINAL_SUMMARY.md)",
]:
    require(stale not in texts["release"],
            f"RELEASE_NOTES must not keep stale support link {stale}")

for required in [
    "](guides/QUICKSTART.md)",
    "](reference/API_REFERENCE.md)",
    "](guides/FAQ.md)",
    "](ARCHITECTURE.md)",
    "](ROADMAP.md)",
]:
    require(required in texts["release"],
            f"RELEASE_NOTES links live target {required}")

for stale in [
    "](QUICKSTART.md)",
    "](docs/API.md)",
]:
    require(stale not in texts["tools"],
            f"TOOLS must not keep stale doc link {stale}")

for required in [
    "](guides/QUICKSTART.md)",
    "](reference/API_REFERENCE.md)",
]:
    require(required in texts["tools"],
            f"TOOLS links live target {required}")

for stale in [
    "](WINSSL_USER_GUIDE.md)",
    "](WINSSL_QUICKSTART.md)",
    "](.claude/plan/WINSSL_COMPLETION_REPORT.md)",
]:
    require(stale not in texts["zero_dep"],
            f"ZERO_DEPENDENCY_DEPLOYMENT must not keep stale doc link {stale}")

for required in [
    "](guides/WINSSL_USER_GUIDE.md)",
    "](guides/WINSSL_QUICKSTART.md)",
    "](test_reports/WINSSL_BACKEND_STATUS_REPORT.md)",
]:
    require(required in texts["zero_dep"],
            f"ZERO_DEPENDENCY_DEPLOYMENT links live target {required}")

for stale in [
    "](ZERO_DEPENDENCY_DEPLOYMENT.md)",
    "](WINSSL_HTTPS_TEST_REPORT.md)",
    "](WINSSL_DESIGN.md)",
    "](../PHASE2_2_COMPLETION_REPORT.md)",
    "](../PHASE2_4_TEST_REPORT.md)",
]:
    require(stale not in texts["winssl_guide"],
            f"WINSSL_USER_GUIDE must not keep stale link {stale}")

for required in [
    "](WINSSL_QUICKSTART.md)",
    "](../ZERO_DEPENDENCY_DEPLOYMENT.md)",
    "](../test_reports/WINSSL_BACKEND_STATUS_REPORT.md)",
    "](../reference/WINSSL_DESIGN.md)",
    "](../reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md)",
    "](../reference/WINSSL_PERFORMANCE_TUNING.md)",
]:
    require(required in texts["winssl_guide"],
            f"WINSSL_USER_GUIDE links live target {required}")

PY

echo "[PASS] active root doc link repair contract passed"

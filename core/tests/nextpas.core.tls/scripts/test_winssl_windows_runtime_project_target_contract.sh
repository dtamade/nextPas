#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() {
  echo "[FAIL] $1"
  exit 1
}

echo "[TEST] winssl windows runtime project target contract"

python3 - "$ROOT_DIR" <<'PY'
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

root = Path(sys.argv[1])
projects = [
    root / "tests/winssl/test_winssl_certificate_loading.lpi",
    root / "tests/winssl/test_winssl_unit_comprehensive.lpi",
    root / "tests/winssl/test_winssl_integration_multi.lpi",
    root / "tests/winssl/test_winssl_session_resumption.lpi",
    root / "tests/integration/test_backend_comparison.lpi",
    root / "tests/winssl/test_winssl_performance.lpi",
    root / "tests/winssl/test_winssl_handshake_debug.lpi",
    root / "tests/winssl/test_winssl_https_client.lpi",
]

allowed_target_os = {None, "", "win64"}
allowed_target_cpu = {None, "", "x86_64"}

for project in projects:
    if not project.is_file():
        print(f"[FAIL] missing project file: {project.relative_to(root)}")
        raise SystemExit(1)

    tree = ET.parse(project)
    codegen = tree.getroot().find("./CompilerOptions/CodeGeneration")
    target_os = None
    target_cpu = None
    if codegen is not None:
        target_os_node = codegen.find("TargetOS")
        target_cpu_node = codegen.find("TargetCPU")
        if target_os_node is not None:
            target_os = target_os_node.get("Value")
        if target_cpu_node is not None:
            target_cpu = target_cpu_node.get("Value")

    rel = project.relative_to(root)
    if target_os not in allowed_target_os:
        print(
            f"[FAIL] {rel} must not hardcode a non-Windows target for Windows runtime validation "
            f"(observed TargetOS={target_os!r})"
        )
        raise SystemExit(1)
    if target_cpu not in allowed_target_cpu:
        print(
            f"[FAIL] {rel} must keep host/x86_64 CPU truth for Windows runtime validation "
            f"(observed TargetCPU={target_cpu!r})"
        )
        raise SystemExit(1)

print("[PASS] winssl windows runtime project target contract passed")
PY

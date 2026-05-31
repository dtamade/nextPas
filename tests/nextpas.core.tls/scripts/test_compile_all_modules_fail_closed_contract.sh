#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/scripts/compile_all_modules.py"

fail() {
  echo "[FAIL] $1"
  exit 1
}

echo "[TEST] compile_all_modules fail-closed contract"

python3 - "$ROOT_DIR" "$SCRIPT_PATH" <<'PY'
import importlib.util
import pathlib
import shutil
import sys

root_dir = pathlib.Path(sys.argv[1])
script_path = pathlib.Path(sys.argv[2])

spec = importlib.util.spec_from_file_location("compile_all_modules", script_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

fixture_src = root_dir / "tmp" / "contract_compile_all_modules_fail_closed_src"
fixture_units = root_dir / "tmp" / "contract_compile_all_modules_fail_closed_units"

if fixture_src.exists():
    shutil.rmtree(fixture_src)
fixture_src.mkdir(parents=True, exist_ok=True)
fixture_units.mkdir(parents=True, exist_ok=True)

for index in range(100):
    (fixture_src / f"unit_{index:03d}.pas").write_text(
        "unit contract_unit;\ninterface\nimplementation\nend.\n",
        encoding="utf-8",
    )

original_src_dir = module.SRC_DIR
original_compile_module = module.compile_module
original_resolve_unit_output_dir = module.resolve_unit_output_dir
original_argv = sys.argv[:]

def fake_compile_module(
    pas_file,
    rebuild,
    timeout_seconds,
    unit_output_dir,
    unit_paths=None,
    fpc_exe=module.DEFAULT_FPC_EXE,
):
    if pas_file.name == "unit_099.pas":
        return False, "", "simulated failure"
    return True, "", ""

try:
    module.SRC_DIR = fixture_src
    module.compile_module = fake_compile_module
    module.resolve_unit_output_dir = lambda raw_dir: (fixture_units, False)
    sys.argv = [str(script_path)]
    exit_code = module.main()
finally:
    module.SRC_DIR = original_src_dir
    module.compile_module = original_compile_module
    module.resolve_unit_output_dir = original_resolve_unit_output_dir
    sys.argv = original_argv

if exit_code == 0:
    print("[FAIL] compile_all_modules should fail closed when even 1/100 modules fails")
    sys.exit(1)

print("[PASS] compile_all_modules rejects a 99% compile success rate")
PY

echo "[PASS] compile_all_modules fail-closed contract passed"

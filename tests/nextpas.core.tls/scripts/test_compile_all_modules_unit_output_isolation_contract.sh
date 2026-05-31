#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/scripts/compile_all_modules.py"

echo "[TEST] compile_all_modules command should include isolated -FU output dir"

python3 - "$ROOT_DIR" "$SCRIPT_PATH" <<'PY'
import importlib.util
import pathlib
import subprocess
import sys

root_dir = pathlib.Path(sys.argv[1])
script_path = pathlib.Path(sys.argv[2])

spec = importlib.util.spec_from_file_location("compile_all_modules", script_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

sample_pas = root_dir / "src" / "nextpas.core.tls.base.pas"
unit_output = root_dir / "tmp" / "contract_units_dir"

cmd = module.build_fpc_command(sample_pas, rebuild=False, unit_output_dir=unit_output)

expected_fu = f"-FU{unit_output}"
if expected_fu not in cmd:
    print("[FAIL] expected isolated unit output flag missing:", expected_fu)
    print("[INFO] cmd:", " ".join(str(x) for x in cmd))
    sys.exit(1)

print("[PASS] isolated unit output flag found:", expected_fu)

captured = {}
original_build = module.build_fpc_command
original_run = subprocess.run

def fake_build_fpc_command(pas_file, rebuild, unit_output_dir, unit_paths=None, fpc_exe=module.DEFAULT_FPC_EXE):
    captured["unit_output_dir"] = pathlib.Path(unit_output_dir)
    return ["fake-fpc"]

class FakeResult:
    returncode = 0
    stdout = ""
    stderr = ""

def fake_run(*args, **kwargs):
    return FakeResult()

module.build_fpc_command = fake_build_fpc_command
subprocess.run = fake_run
try:
    ok, stdout, stderr = module.compile_module(sample_pas, False, 1, unit_output)
finally:
    module.build_fpc_command = original_build
    subprocess.run = original_run

expected_module_dir = unit_output / "nextpas.core.tls.base"
if captured.get("unit_output_dir") != expected_module_dir:
    print("[FAIL] compile_module should isolate each unit into its own subdir")
    print("[INFO] expected:", expected_module_dir)
    print("[INFO] actual:", captured.get("unit_output_dir"))
    sys.exit(1)

if not ok or stdout or stderr:
    print("[FAIL] compile_module smoke stub should succeed cleanly")
    sys.exit(1)

print("[PASS] compile_module isolates per-unit output directory:", expected_module_dir)
PY

echo "[PASS] compile_all_modules unit output isolation contract"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/scripts/compile_all_modules.py"

fail() {
  echo "[FAIL] $1"
  exit 1
}

echo "[TEST] compile_all_modules fpc host/units override contract"

if ! rg -F --quiet -- 'DEFAULT_FPC_EXE = os.environ.get("FAFAFA_FPC_EXE", "fpc")' "$SCRIPT_PATH"; then
  fail "script should define DEFAULT_FPC_EXE from FAFAFA_FPC_EXE env"
fi

if ! rg -F --quiet -- 'DEFAULT_FPC_UNITS_BASE = os.environ.get("FAFAFA_FPC_UNITS_BASE", "")' "$SCRIPT_PATH"; then
  fail "script should define DEFAULT_FPC_UNITS_BASE from FAFAFA_FPC_UNITS_BASE env"
fi

if ! rg -F --quiet -- '--fpc-exe' "$SCRIPT_PATH"; then
  fail "script should expose --fpc-exe option"
fi

if ! rg -F --quiet -- '--fpc-units-base' "$SCRIPT_PATH"; then
  fail "script should expose --fpc-units-base option"
fi

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

units_base = root_dir / "tmp" / "contract_compile_all_modules_units_base"
unit_output = root_dir / "tmp" / "contract_compile_all_modules_units_out"
sample_pas = root_dir / "src" / "nextpas.core.tls.base.pas"

if units_base.exists():
    shutil.rmtree(units_base)
units_base.mkdir(parents=True, exist_ok=True)
(units_base / "rtl-objpas").mkdir(parents=True, exist_ok=True)
(units_base / "fcl-base").mkdir(parents=True, exist_ok=True)

unit_paths = module.build_unit_paths(units_base)

if (units_base / "rtl-objpas") not in unit_paths:
    print("[FAIL] build_unit_paths should include rtl-objpas under provided base")
    sys.exit(1)

if (root_dir / "src") not in unit_paths:
    print("[FAIL] build_unit_paths should include project src path")
    sys.exit(1)

cmd = module.build_fpc_command(
    sample_pas,
    rebuild=False,
    unit_output_dir=unit_output,
    unit_paths=unit_paths,
    fpc_exe="contract-fpc",
)

if cmd[0] != "contract-fpc":
    print("[FAIL] build_fpc_command should use injected fpc_exe")
    print("[INFO] cmd:", " ".join(str(x) for x in cmd))
    sys.exit(1)

expected_fu = f"-FU{unit_output}"
if expected_fu not in cmd:
    print("[FAIL] build_fpc_command should preserve isolated -FU output dir")
    print("[INFO] cmd:", " ".join(str(x) for x in cmd))
    sys.exit(1)

print("[PASS] compile_all_modules host/units override dynamic checks passed")
PY

echo "[PASS] compile_all_modules fpc host/units override contract passed"

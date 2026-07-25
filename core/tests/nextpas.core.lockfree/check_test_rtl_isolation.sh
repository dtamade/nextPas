#!/usr/bin/env bash
# F-001 regression: atomic/lockfree tests/examples/benches must not uses FPC RTL.
# Fast path: Python scan of uses-blocks only.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export CORE_ROOT
python3 - <<'PY'
import os, re, sys
from pathlib import Path

core = Path(os.environ["CORE_ROOT"])
rtl = re.compile(r"\b(SysUtils|Classes|Math|Windows|BaseUnix|Unix|TypInfo|StrUtils|DateUtils|SyncObjs|Contnrs)\b")
str_or_concat = re.compile(
    r"['\"].*(SysUtils|Classes|Math|Windows|BaseUnix|Unix)|"
    r"\+\s*L(SysUtils|Classes|Math|Windows|BaseUnix|Unix)"
)
roots = [
    core / "tests/nextpas.core.lockfree",
    core / "tests/nextpas.core.atomic",
    core / "examples/nextpas.core.lockfree",
    core / "benchmarks/nextpas.core.lockfree",
    core / "benchmarks/nextpas.core.atomic",
]
files = []
for r in roots:
    if r.is_dir():
        files.extend(r.rglob("*.pas"))
        files.extend(r.rglob("*.lpr"))
        files.extend(r.rglob("*.inc"))
ex = core / "examples/lockfree_example.lpr"
if ex.is_file():
    files.append(ex)

fails = []
for path in files:
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        continue
    in_uses = False
    for i, line in enumerate(text.splitlines(), 1):
        # strip // and simple {} comments
        s = re.sub(r"\{[^}]*\}", "", line)
        s = re.sub(r"//.*", "", s)
        if re.search(r"^\s*uses\b", s, re.I):
            in_uses = True
        if in_uses:
            if rtl.search(s) and not str_or_concat.search(s):
                fails.append(f"{path}:{i}: {line.rstrip()}")
            if ";" in s:
                in_uses = False

if fails:
    for f in fails:
        print(f"RTL-isolation-fail: {f}")
    print(f"lockfree-test-rtl-isolation-status=fail count={len(fails)}")
    sys.exit(1)
print("lockfree-test-rtl-isolation-status=pass")
sys.exit(0)
PY

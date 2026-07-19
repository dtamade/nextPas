#!/usr/bin/env bash
# Count "meaningful" self-test processes for Go/Rust scale bar.
# Countable = Suite.Test( registrations + TestTable case expansions
#   + AppendFilterCase / Append*Case helpers + static SetLength(cases, N)
# Excludes: stress 10k empty loops, pure compilation of helpers.
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
TESTS="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
MIN_COUNT="${SCALE_MIN:-1800}"

python3 - "$TESTS" "$MIN_COUNT" <<'PY'
import re, sys
from pathlib import Path

tests_root = Path(sys.argv[1])
min_count = int(sys.argv[2])

# suites excluded from scale inflation / empty stress
EXCLUDE_DIRS = {"test_stress", "test_scale_report", "test_api_source_contracts",
                "test_runner_source_contracts", "test_perf_bench"}

total = 0
per = {}

def add(suite, n, reason=""):
    global total
    if n <= 0:
        return
    per[suite] = per.get(suite, 0) + n
    total += n

for lpr in sorted(tests_root.rglob("*.lpr")):
    suite = lpr.parent.name
    if suite in EXCLUDE_DIRS:
        continue
    text = lpr.read_text(errors="replace")
    # 1) Suite.Test('name' or "name"
    n_test = len(re.findall(r'''\.Test\s*\(\s*['"]''', text))
    add(suite, n_test)

    # 2) SetLength(<ident>, N) near TestTable — count N when N is integer literal
    #    and a TestTable appears within following 40 lines
    lines = text.splitlines()
    for i, line in enumerate(lines):
        m = re.search(r'SetLength\s*\(\s*\w+\s*,\s*(\d+)\s*\)', line)
        if not m:
            continue
        n = int(m.group(1))
        if n < 2 or n > 5000:
            continue
        window = "\n".join(lines[i:i+40])
        if re.search(r'TestTable\s*\(', window):
            add(suite, n)

    # 3) AppendFilterCase / Append*Case( helper calls (one case each)
    n_append = len(re.findall(r'''\bAppend\w*Case\s*\(''', text))
    add(suite, n_append)

print("=== Scale report (countable processes) ===")
for k in sorted(per):
    print(f"  {k:28} {per[k]:5}")
print(f"TOTAL countable: {total}")
print(f"MIN required:    {min_count}")
if total < min_count:
    print(f"FAIL: scale {total} < {min_count}")
    sys.exit(1)
print(f"PASS: scale >= {min_count}")
sys.exit(0)
PY

#!/usr/bin/env bash
# Count "meaningful" self-test processes for Go/Rust scale bar.
#
# Countable (v8.14 rules):
#   1) Suite.Test( 'name' ... registrations
#   2) Suite.TestSubtest( 'name' ... registrations  (Go t.Run style)
#   3) TestTable expansions: SetLength(cases, N) near TestTable(
#   4) Append*Case( helper calls (one case each)
#
# Excludes: stress 10k empty loops; pure shell contract suites;
#           test_perf_bench (optional CI).
#
# v8.25 quality gate: low-signal TestTable share capped.
# v8.31: SCALE_MIN=7500, FAIL_PATH≥35%, LOW_SIGNAL≤25%;
#         MIN_NON_TABLE (Test+TestSubtest+AppendCase) softens TestTable domination (F-13).
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
TESTS="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
MIN_COUNT="${SCALE_MIN:-7500}"
MIN_FAIL_RATIO="${FAIL_PATH_MIN_RATIO:-0.35}"
MAX_LOW_SIGNAL_RATIO="${LOW_SIGNAL_MAX_RATIO:-0.25}"
# Non-table floor: named Test/TestSubtest/AppendCase (not TestTable expansions).
MIN_NON_TABLE="${MIN_NON_TABLE:-1200}"

python3 - "$TESTS" "$MIN_COUNT" "$MIN_FAIL_RATIO" "$MAX_LOW_SIGNAL_RATIO" "$MIN_NON_TABLE" <<'PY'
import re, sys
from pathlib import Path
from collections import defaultdict

tests_root = Path(sys.argv[1])
min_count = int(sys.argv[2])
min_fail_ratio = float(sys.argv[3])
max_low_signal_ratio = float(sys.argv[4])
min_non_table = int(sys.argv[5])

EXCLUDE_DIRS = {
    "test_stress",
    "test_scale_report",
    "test_api_source_contracts",
    "test_runner_source_contracts",
    "test_perf_bench",
}

total = 0
fail_path_hint = 0
low_signal = 0
per = {}
per_fail = defaultdict(int)
per_low = defaultdict(int)
breakdown = {"Test": 0, "TestSubtest": 0, "TestTable": 0, "AppendCase": 0}

FAIL_PATH_RE = re.compile(
    r"fail[-_ ]?path|ExpectFail|negative|softfail|SoftFail|SoftCheck|must fail|should fail",
    re.I,
)
LOW_SIGNAL_RE = re.compile(
    r"identity|meta-|B26 discover name|name contract|pad[-_ ]?table|scale bulk|bulk identity",
    re.I,
)

def add(suite, n, kind=""):
    global total
    if n <= 0:
        return
    per[suite] = per.get(suite, 0) + n
    total += n
    if kind in breakdown:
        breakdown[kind] += n

for lpr in sorted(tests_root.rglob("*.lpr")):
    suite = lpr.parent.name
    if suite in EXCLUDE_DIRS:
        continue
    text = lpr.read_text(errors="replace")

    n_test = len(re.findall(
        r'''\.Test(?!Subtest|Table|Seq)\s*\(\s*['"]''', text))
    add(suite, n_test, "Test")

    n_sub = len(re.findall(r'''\.TestSubtest\s*\(\s*['"]''', text))
    add(suite, n_sub, "TestSubtest")

    lines = text.splitlines()
    for i, line in enumerate(lines):
        m = re.search(r'SetLength\s*\(\s*\w+\s*,\s*(\d+)\s*\)', line)
        if not m:
            continue
        n = int(m.group(1))
        if n < 2 or n > 5000:
            continue
        window = "\n".join(lines[i:i+40])
        if not re.search(r'TestTable\s*\(', window):
            continue
        add(suite, n, "TestTable")
        if FAIL_PATH_RE.search(window):
            fail_path_hint += n
            per_fail[suite] += n
        elif LOW_SIGNAL_RE.search(window):
            low_signal += n
            per_low[suite] += n

    n_append = len(re.findall(r'''\bAppend\w*Case\s*\(''', text))
    add(suite, n_append, "AppendCase")
    n_neg_append = len(re.findall(r'''\bAppend\w*Case\s*\([^)]*'0'\s*\)''', text))
    fail_path_hint += n_neg_append
    per_fail[suite] += n_neg_append

print("=== Scale report (countable processes) ===")
print("rules: Test + TestSubtest + TestTable(N) + Append*Case")
print(f"  breakdown: Test={breakdown['Test']} TestSubtest={breakdown['TestSubtest']} "
      f"TestTable={breakdown['TestTable']} AppendCase={breakdown['AppendCase']}")
print("  per-suite (total / fail-path / low-signal):")
for k in sorted(per):
    print(f"  {k:28} {per[k]:5}  fp={per_fail.get(k, 0):5}  low={per_low.get(k, 0):5}")
non_table = breakdown["Test"] + breakdown["TestSubtest"] + breakdown["AppendCase"]
print(f"TOTAL countable: {total}")
print(f"MIN required:    {min_count}")
print(f"non-table count: {non_table}  (Test+Subtest+Append; MIN_NON_TABLE={min_non_table})")
print(f"TestTable share: {100.0 * breakdown['TestTable'] / total if total else 0:.1f}%")
failed = False
if total > 0:
    ratio = fail_path_hint / total
    low_ratio = low_signal / total
    print(f"fail-path hint:  {fail_path_hint} (~{100.0 * ratio:.1f}% of countable; heuristic)")
    print(f"MIN fail-path:   {min_fail_ratio:.0%} of countable")
    print(f"low-signal hint: {low_signal} (~{100.0 * low_ratio:.1f}% of countable; identity/meta tables)")
    print(f"MAX low-signal:  {max_low_signal_ratio:.0%} of countable")
    if ratio < min_fail_ratio:
        print(f"FAIL: fail-path ratio {ratio:.3f} < {min_fail_ratio:.3f}")
        failed = True
    if low_ratio > max_low_signal_ratio:
        print(f"FAIL: low-signal ratio {low_ratio:.3f} > {max_low_signal_ratio:.3f}")
        failed = True
else:
    print("fail-path hint:  0 (no countable processes)")
    failed = True
if total < min_count:
    print(f"FAIL: scale {total} < {min_count}")
    failed = True
if non_table < min_non_table:
    print(f"FAIL: non-table count {non_table} < {min_non_table}")
    failed = True
if failed:
    sys.exit(1)
print(f"PASS: scale >= {min_count}, fail-path >= {min_fail_ratio:.0%}, "
      f"low-signal <= {max_low_signal_ratio:.0%}, non-table >= {min_non_table}")
sys.exit(0)
PY

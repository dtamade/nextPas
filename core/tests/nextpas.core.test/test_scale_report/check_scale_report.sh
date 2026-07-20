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
# v8.25 quality gate (M6): low-signal TestTable share is reported and capped.
# Low-signal = TestTable whose local window lacks fail-path keywords AND matches
# identity/meta/pad/name-contract heuristics (B3 identity bulk, B26 meta names).
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
TESTS="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
MIN_COUNT="${SCALE_MIN:-5500}"
# Fail-path share of countable processes (heuristic: ExpectFail / negative tables / Append*Case '0')
MIN_FAIL_RATIO="${FAIL_PATH_MIN_RATIO:-0.30}"
# Max share of countable processes that may be low-signal identity-style tables
MAX_LOW_SIGNAL_RATIO="${LOW_SIGNAL_MAX_RATIO:-0.55}"

python3 - "$TESTS" "$MIN_COUNT" "$MIN_FAIL_RATIO" "$MAX_LOW_SIGNAL_RATIO" <<'PY'
import re, sys
from pathlib import Path

tests_root = Path(sys.argv[1])
min_count = int(sys.argv[2])
min_fail_ratio = float(sys.argv[3])
max_low_signal_ratio = float(sys.argv[4])

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
breakdown = {"Test": 0, "TestSubtest": 0, "TestTable": 0, "AppendCase": 0}

FAIL_PATH_RE = re.compile(
    r"fail[-_ ]?path|ExpectFail|negative|softfail|SoftFail|must fail|should fail",
    re.I,
)
LOW_SIGNAL_RE = re.compile(
    r"identity|meta-|B26|name contract|pad[-_ ]?table|scale bulk|bulk identity",
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

    # 1) Suite.Test('name' — exclude TestSubtest / TestTable / TestSeq
    n_test = len(re.findall(
        r'''\.Test(?!Subtest|Table|Seq)\s*\(\s*['"]''', text))
    add(suite, n_test, "Test")

    # 2) Suite.TestSubtest(
    n_sub = len(re.findall(r'''\.TestSubtest\s*\(\s*['"]''', text))
    add(suite, n_sub, "TestSubtest")

    # 3) SetLength(..., N) near TestTable
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
        elif LOW_SIGNAL_RE.search(window):
            # identity/meta bulk without fail-path markers
            low_signal += n
        # else: neutral table (not counted as fail-path nor low-signal)

    # 4) Append*Case(
    n_append = len(re.findall(r'''\bAppend\w*Case\s*\(''', text))
    add(suite, n_append, "AppendCase")
    n_neg_append = len(re.findall(r'''\bAppend\w*Case\s*\([^)]*'0'\s*\)''', text))
    fail_path_hint += n_neg_append

print("=== Scale report (countable processes) ===")
print("rules: Test + TestSubtest + TestTable(N) + Append*Case")
print(f"  breakdown: Test={breakdown['Test']} TestSubtest={breakdown['TestSubtest']} "
      f"TestTable={breakdown['TestTable']} AppendCase={breakdown['AppendCase']}")
for k in sorted(per):
    print(f"  {k:28} {per[k]:5}")
print(f"TOTAL countable: {total}")
print(f"MIN required:    {min_count}")
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
if failed:
    sys.exit(1)
print(f"PASS: scale >= {min_count}, fail-path >= {min_fail_ratio:.0%}, "
      f"low-signal <= {max_low_signal_ratio:.0%}")
sys.exit(0)
PY

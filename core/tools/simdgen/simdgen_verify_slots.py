#!/usr/bin/env python3
"""
simdgen_verify_slots.py - Dispatch slot 完整性校验

校验分两层:
1. 硬门禁: baseline.inc (FillBaseDispatchTable) 必须为 dispatch_slots.json 中
   每个 function/procedure slot 提供 scalar fallback —— 缺失即非零退出。
   无法解算到分组表字段的 slot 名同样立即失败 (fail-close)。
2. 信息层: 各 backend register.inc 对 batch slot 的优化覆盖率。batch slot
   允许落在 scalar fallback 上, 覆盖率只报告、不作为失败条件。

Usage:
    python3 tools/simdgen/simdgen_verify_slots.py
"""

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from simdgen import _load_group_fields, _resolve_slot_group

ROOT = Path(__file__).parent.parent.parent
SLOTS_JSON = Path(__file__).parent / "ops" / "dispatch_slots.json"

BACKENDS = {
    "avx2": ROOT / "src" / "nextpas.core.simd.avx2.register.inc",
    "sse2": ROOT / "src" / "nextpas.core.simd.sse2.register.inc",
}

BASELINE_FILE = ROOT / "src" / "nextpas.core.simd.dispatch.baseline.inc"

# Phase 19 分组布局: dispatchTable.<Group>.<Field> := @Impl;
ASSIGN_RE = re.compile(r'dispatchTable\.(\w+)\.(\w+)\s*:=')


def load_slots() -> list[dict]:
    with open(SLOTS_JSON) as f:
        data = json.load(f)
    return data["slots"]


def extract_assignments(filepath: Path) -> set[tuple[str, str]]:
    """Extract (group, field) pairs assigned via dispatchTable in a source file."""
    if not filepath.exists():
        return set()
    return set(ASSIGN_RE.findall(filepath.read_text()))


def main() -> int:
    slots = load_slots()
    groups = _load_group_fields()

    func_slots = [s for s in slots if s["kind"] in ("function", "procedure")]
    # slot 名 -> 分组表 (group, field); 解算失败会抛 RuntimeError (fail-close)
    expected = {s["name"]: _resolve_slot_group(s["name"], groups) for s in func_slots}
    batch_expected = {expected[s["name"]] for s in func_slots if s["category"] == "batch"}

    print("=== Dispatch Slot Integrity Check ===")
    print(f"Total slots defined: {len(slots)}")
    print(f"Function/procedure slots: {len(func_slots)}")
    print(f"Batch slots: {len(batch_expected)}")
    print()

    baseline_registered = extract_assignments(BASELINE_FILE)
    scalar_missing = sorted(
        name for name, gf in expected.items() if gf not in baseline_registered)

    print("[Scalar Defaults] (hard gate)")
    print(f"  Registered: {len(expected) - len(scalar_missing)}/{len(expected)}")
    if scalar_missing:
        print(f"  MISSING ({len(scalar_missing)}):")
        for name in scalar_missing[:10]:
            group, field = expected[name]
            print(f"    - {name} (dispatchTable.{group}.{field})")
        if len(scalar_missing) > 10:
            print(f"    ... and {len(scalar_missing) - 10} more")
    else:
        print("  All slots have scalar fallback ✓")
    print()

    for backend_name, filepath in BACKENDS.items():
        registered = extract_assignments(filepath)
        batch_registered = registered & batch_expected
        batch_missing = batch_expected - registered

        print(f"[{backend_name.upper()} Backend] (informational)")
        print(f"  Total registered: {len(registered)}")
        print(f"  Batch coverage: {len(batch_registered)}/{len(batch_expected)}")
        if batch_missing:
            print(f"  Batch slots using scalar fallback ({len(batch_missing)}):")
            for group, field in sorted(batch_missing)[:10]:
                print(f"    - {group}.{field}")
            if len(batch_missing) > 10:
                print(f"    ... and {len(batch_missing) - 10} more")
        else:
            print("  All batch slots have optimized impl ✓")
        print()

    print("=== Summary ===")
    avx2_batch = extract_assignments(BACKENDS["avx2"]) & batch_expected
    sse2_batch = extract_assignments(BACKENDS["sse2"]) & batch_expected
    print("Batch slot coverage:")
    print(f"  AVX2: {len(avx2_batch)}/{len(batch_expected)} ({100 * len(avx2_batch) // len(batch_expected)}%)")
    print(f"  SSE2: {len(sse2_batch)}/{len(batch_expected)} ({100 * len(sse2_batch) // len(batch_expected)}%)")

    if scalar_missing:
        print()
        print(f"FAIL: {len(scalar_missing)} slot(s) lack scalar fallback in "
              f"{BASELINE_FILE.name}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

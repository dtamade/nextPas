#!/usr/bin/env python3
"""
simdgen_verify_slots.py - Dispatch slot 完整性校验

检测各 backend register.inc 中是否有遗漏的 slot 注册。
对比 dispatch_slots.json 定义与实际注册代码。

Usage:
    python3 tools/simdgen/simdgen_verify_slots.py
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
SLOTS_JSON = Path(__file__).parent / "ops" / "dispatch_slots.json"

BACKENDS = {
    "avx2": ROOT / "src" / "nextpas.core.simd.avx2.register.inc",
    "sse2": ROOT / "src" / "nextpas.core.simd.sse2.register.inc",
}

SCALAR_FILE = ROOT / "src" / "nextpas.core.simd.dispatch.pas"


def load_slots():
    with open(SLOTS_JSON) as f:
        data = json.load(f)
    return data["slots"]


def extract_registered_slots(filepath: Path) -> set[str]:
    """Extract slot names assigned in a register.inc file."""
    if not filepath.exists():
        return set()
    content = filepath.read_text()
    pattern = re.compile(r'dispatchTable\.(\w+)\s*:=')
    return set(pattern.findall(content))


def extract_scalar_defaults() -> set[str]:
    """Extract slots assigned in FillBaseDispatchTable."""
    content = SCALAR_FILE.read_text()
    # Find FillBaseDispatchTable procedure
    start = content.find("procedure FillBaseDispatchTable")
    if start == -1:
        start = content.find("procedure FillScalarDefaults")
    if start == -1:
        return set()
    end = content.find("\nend;", start)
    section = content[start:end]
    pattern = re.compile(r'dispatchTable\.(\w+)\s*:=')
    return set(pattern.findall(section))


def main():
    slots = load_slots()
    all_slot_names = {s["name"] for s in slots}
    batch_slots = {s["name"] for s in slots if s["category"] == "batch"}

    print(f"=== Dispatch Slot Integrity Check ===")
    print(f"Total slots defined: {len(all_slot_names)}")
    print(f"Batch slots: {len(batch_slots)}")
    print()

    # Check scalar defaults
    scalar_registered = extract_scalar_defaults()
    scalar_missing = all_slot_names - scalar_registered
    # Filter out non-function slots (Backend, BackendInfo, etc.)
    func_slots = {s["name"] for s in slots if s["kind"] in ("function", "procedure")}
    scalar_missing = func_slots - scalar_registered

    print(f"[Scalar Defaults]")
    print(f"  Registered: {len(scalar_registered & func_slots)}/{len(func_slots)}")
    if scalar_missing:
        print(f"  MISSING ({len(scalar_missing)}):")
        for name in sorted(scalar_missing)[:10]:
            print(f"    - {name}")
        if len(scalar_missing) > 10:
            print(f"    ... and {len(scalar_missing) - 10} more")
    else:
        print(f"  All slots have scalar fallback ✓")
    print()

    # Check each backend
    issues = 0
    for backend_name, filepath in BACKENDS.items():
        registered = extract_registered_slots(filepath)
        # Only check batch slots for backend coverage (vector slots may intentionally use scalar)
        batch_registered = registered & batch_slots
        batch_missing = batch_slots - registered

        print(f"[{backend_name.upper()} Backend]")
        print(f"  Total registered: {len(registered)}")
        print(f"  Batch coverage: {len(batch_registered)}/{len(batch_slots)}")
        if batch_missing:
            print(f"  Batch slots using scalar fallback ({len(batch_missing)}):")
            for name in sorted(batch_missing)[:10]:
                print(f"    - {name}")
            if len(batch_missing) > 10:
                print(f"    ... and {len(batch_missing) - 10} more")
        else:
            print(f"  All batch slots have optimized impl ✓")
        print()

    # Summary
    print("=== Summary ===")
    avx2_batch = extract_registered_slots(BACKENDS["avx2"]) & batch_slots
    sse2_batch = extract_registered_slots(BACKENDS["sse2"]) & batch_slots
    print(f"Batch slot coverage:")
    print(f"  AVX2: {len(avx2_batch)}/{len(batch_slots)} ({100*len(avx2_batch)//len(batch_slots)}%)")
    print(f"  SSE2: {len(sse2_batch)}/{len(batch_slots)} ({100*len(sse2_batch)//len(batch_slots)}%)")

    return 0


if __name__ == "__main__":
    sys.exit(main())

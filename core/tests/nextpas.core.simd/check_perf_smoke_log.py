#!/usr/bin/env python3
"""Validate SIMD perf-smoke benchmark output."""

from __future__ import annotations

import argparse
from pathlib import Path


ZERO_SPEEDUP_ROWS = {
    "MemEqual",
    "MemFindByte",
    "SumBytes",
    "CountByte",
    "BitsetPopCount",
    "ArrayAddF32",
    "ArrayMulF32",
    "ArrayMulScalarF32",
    "ArrayAxpyF32",
    "VecF32x4Add",
    "VecF32x4Mul",
    "VecF32x4Div",
    "VecI32x4Add",
    "VecF32x4Dot",
    "VecF32x8DotApi",
    "VecF32x8DotBatch",
    "ArrSumF32",
    "ArrSumF64",
    "ArrMinMaxF32",
    "ArrMinMaxF64",
    "ArrVarF32",
    "ArrVarF64",
    "ArrKahanF32",
    "ArrKahanF64",
}

MEMORY_ROWS = {
    "MemEqual",
    "MemFindByte",
    "SumBytes",
    "CountByte",
    "BitsetPopCount",
}

ARRAY_F32_ROWS = {
    "ArrayAddF32",
    "ArrayMulF32",
    "ArrayMulScalarF32",
    "ArrayAxpyF32",
}

PUBLIC_ABI_GROUPS = [
    ("HotMemEqPubCache", "HotMemEqPubGet", "HotMemEqDispGet"),
    ("HotSumPubCache", "HotSumPubGet", "HotSumDispGet"),
]

PUBLIC_ABI_ROWS = {name for group in PUBLIC_ABI_GROUPS for name in group}


def parse_speedup_rows(text: str) -> dict[str, float]:
    rows: dict[str, float] = {}
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        parts = line.split()
        if len(parts) < 2:
            continue
        name = parts[0]
        speedup = parts[-1]
        if not speedup.endswith("x"):
            continue
        try:
            rows[name] = float(speedup[:-1])
        except ValueError:
            continue
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description="Check SIMD perf-smoke benchmark log")
    parser.add_argument("log_file")
    args = parser.parse_args()

    log_path = Path(args.log_file)
    if not log_path.exists():
        print(f"[PERF] FAILED: benchmark log not found: {log_path}")
        return 2

    text = log_path.read_text(encoding="utf-8", errors="ignore")
    if "=== SIMD Benchmark (" not in text:
        print(f"[PERF] FAILED: benchmark header not found in {log_path}")
        return 1

    if "/Scalar)" in text:
        print("[PERF] FAILED (active backend is Scalar; perf-smoke requires non-scalar backend evidence)")
        return 1

    rows = parse_speedup_rows(text)

    missing_array_f32 = [name for name in sorted(ARRAY_F32_ROWS) if name not in rows]
    if missing_array_f32:
        print("[PERF] FAILED: ArrayF32 benchmark rows missing")
        for name in missing_array_f32:
            print(f"  - {name}")
        return 1

    zero_speedups = [name for name in sorted(ZERO_SPEEDUP_ROWS | PUBLIC_ABI_ROWS) if rows.get(name) == 0.0]
    if zero_speedups:
        print("[PERF] FAILED: zero speedup rows detected")
        for name in zero_speedups:
            print(f"  - {name}=0.00x")
        return 1

    memory_regressions = [name for name in sorted(MEMORY_ROWS) if name in rows and rows[name] < 1.0]
    if memory_regressions:
        print("[PERF] FAILED: memory-facade speedup < 1.00x")
        for name in memory_regressions:
            print(f"  - {name}={rows[name]:.2f}x")
        return 1

    missing_public_abi = []
    cache_getter_notes = []
    ordering_notes = []
    for cache_name, getter_name, dispatch_name in PUBLIC_ABI_GROUPS:
        for name in (cache_name, getter_name, dispatch_name):
            if name not in rows:
                missing_public_abi.append(name)
        if any(name not in rows for name in (cache_name, getter_name, dispatch_name)):
            continue

        cache_speedup = rows[cache_name]
        getter_speedup = rows[getter_name]
        dispatch_speedup = rows[dispatch_name]

        if cache_speedup < getter_speedup:
            cache_getter_notes.append(
                f"{cache_name}={cache_speedup:.2f}x below {getter_name}={getter_speedup:.2f}x "
                "(allowed: GetSimdPublicApi is a very thin inline getter)"
            )
        if getter_speedup <= dispatch_speedup:
            ordering_notes.append(
                f"{getter_name}={getter_speedup:.2f}x below {dispatch_name}={dispatch_speedup:.2f}x "
                "(observed only: tiny hot-path microbenchmarks can reorder by CPU/codegen noise)"
            )

    if missing_public_abi:
        print("[PERF] FAILED: public ABI hot-path benchmark rows missing")
        for name in sorted(set(missing_public_abi)):
            print(f"  - {name}")
        return 1

    if cache_getter_notes:
        print("[PERF] NOTE: cached public ABI table was not faster than repeated getter in this sample")
        for item in cache_getter_notes:
            print(f"  - {item}")

    if ordering_notes:
        print("[PERF] NOTE: public ABI hot-path relative ordering differed in this sample")
        for item in ordering_notes:
            print(f"  - {item}")

    print("[PERF] OK (non-scalar backend benchmark looks healthy; required rows present)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

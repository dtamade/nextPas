#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


TEST_DIR = Path(__file__).resolve().parent
REPO_ROOT = TEST_DIR.parents[3]
SOURCE = REPO_ROOT / "core" / "src" / "nextpas.core.hash.wyhash.pas"


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    errors: list[str] = []

    native_load = re.compile(
        r"\bP(?:UInt(?:32|64)|Cardinal|QWord|LongWord)\s*\([^)]*\)\s*\^",
        re.IGNORECASE,
    )
    if native_load.search(source):
        errors.append(
            "WyHash must not use native integer pointer dereference for byte loads"
        )

    for helper, shifts in {
        "WyR4": ("shl 8", "shl 16", "shl 24"),
        "WyR8": ("shl 8", "shl 16", "shl 24", "shl 32", "shl 40", "shl 48", "shl 56"),
    }.items():
        match = re.search(
            rf"function\s+{helper}\s*\([^)]*\)\s*:\s*UInt64\s*;.*?begin(?P<body>.*?)end\s*;",
            source,
            re.IGNORECASE | re.DOTALL,
        )
        if not match:
            errors.append(f"{helper} must remain a local byte-load helper")
            continue
        body = match.group("body")
        for shift in shifts:
            if shift not in body:
                errors.append(f"{helper} must assemble bytes with explicit little-endian {shift}")

    if errors:
        print("wyhash portability source contract failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("wyhash portability source contract passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())

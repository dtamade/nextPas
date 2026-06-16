#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


TEST_DIR = Path(__file__).resolve().parent
REPO_ROOT = TEST_DIR.parents[3]
SOURCE = REPO_ROOT / "core" / "src" / "nextpas.core.hash.wyhash.pas"
WYHASH_TEST = TEST_DIR / "test_wyhash.lpr"


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    test_source = WYHASH_TEST.read_text(encoding="utf-8")
    errors: list[str] = []

    native_load = re.compile(
        r"\bP(?:UInt(?:32|64)|Cardinal|QWord|LongWord)\s*\([^)]*\)\s*\^",
        re.IGNORECASE,
    )
    if native_load.search(source):
        errors.append(
            "WyHash must not use native integer pointer dereference for byte loads"
        )

    native_fixture_store = re.compile(
        r"\bP(?:Int|UInt)(?:32|64)?\s*\([^)]*\)\s*\^\s*:=",
        re.IGNORECASE,
    )
    if native_fixture_store.search(test_source):
        errors.append(
            "WyHash tests must not build fixtures with native integer pointer stores"
        )

    banned_runtime_markers = [
        ("bucket distribution array", "Buckets: array"),
        ("bucket range threshold", "Buckets[I] > 400"),
        ("distribution uniformity label", "distribution uniformity"),
    ]
    for label, marker in banned_runtime_markers:
        if marker in test_source:
            errors.append(f"WyHash tests must not use {label}")

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

    long_branch = re.search(
        r"else\s*begin(?P<body>.*?)Result\s*:=\s*WyMix",
        source,
        re.IGNORECASE | re.DOTALL,
    )
    if "else if ALen < 48 then" not in source:
        errors.append("WyHash 48-byte input must enter the long-lane branch")
    if "while i + 16 < ALen do" not in source:
        errors.append("WyHash 16-byte tail loop must not re-mix the final 16-byte tail")
    if not long_branch:
        errors.append("WyHash long-input branch shape changed; review >48-byte lane contract")
    else:
        body = long_branch.group("body")
        for marker in ("see1", "see2", "seed xor see1 xor see2"):
            if marker not in body:
                errors.append(
                    "WyHash >48-byte branch must keep independent see1/see2 lanes "
                    f"and final merge marker: {marker}"
                )

    required_vectors = [
        "TestWyHashDeterministicRegressionVectors",
        "WyHashStr('abc', 0)",
        "WyHashStr('hello', 42)",
        "WyHashStr32('abc', 42)",
        "$C11B4B9E7A314A11",
        "$D047C5859F97FB1B",
        "$22DCD7F50FDCA435",
        "$222A591E60007D73",
        "$176750A3DF14201F",
        "$A027DA0188933F32",
        "$1BFFD740AA70C33A",
        "$5F531FDFBF6940BD",
    ]
    for vector in required_vectors:
        if vector not in test_source:
            errors.append(f"WyHash boundary vector must stay pinned: {vector}")
    if "$8F3F90705D27CB20" in test_source:
        errors.append("WyHash tests must not preserve the old single-seed 50-byte fixture")

    if errors:
        print("wyhash portability source contract failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("wyhash portability source contract passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())

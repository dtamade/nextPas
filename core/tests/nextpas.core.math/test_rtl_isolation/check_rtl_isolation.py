#!/usr/bin/env python3
"""Fail production math/simd units that directly uses forbidden FPC RTL units.

Only nextpas.core.system (and its system.* sub-facades) may bind FPC RTL units.
math/simd production code must go through framework owners (math, platform, errors).

Test trees may still use RTL during migration; report them as WARN unless --fail-tests.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


SUMMARY_PREFIX = "MATH_SIMD_RTL_ISOLATION"

FORBIDDEN_UNITS = (
    "Math",
    "SysUtils",
    "Classes",
    "Windows",
    "Unix",
    "BaseUnix",
    "Dos",
    "TypInfo",
    "Types",
    "StrUtils",
    "DateUtils",
)

# Unit token as a uses-clause identifier (not Math.FMod style member access).
UNIT_TOKEN_RE = re.compile(
    r"(?<![\w.])(" + "|".join(re.escape(u) for u in FORBIDDEN_UNITS) + r")(?![\w.])"
)

USES_BLOCK_RE = re.compile(
    r"(?is)\buses\b(.*?);",
)

PRODUCTION_GLOBS = (
    "src/nextpas.core.math*.pas",
    "src/nextpas.core.math*.inc",
    "src/nextpas.core.simd*.pas",
    "src/nextpas.core.simd*.inc",
)

TEST_GLOBS = (
    "tests/nextpas.core.math/**/*.pas",
    "tests/nextpas.core.math/**/*.lpr",
    "tests/nextpas.core.simd/**/*.pas",
    "tests/nextpas.core.simd/**/*.lpr",
    "tests/nextpas.core.simd.cpuinfo/**/*.pas",
    "tests/nextpas.core.simd.cpuinfo/**/*.lpr",
    "examples/nextpas.core.math/**/*.pas",
    "examples/nextpas.core.math/**/*.lpr",
    "benchmarks/nextpas.core.math/**/*.pas",
    "benchmarks/nextpas.core.math/**/*.lpr",
)


def strip_comments(text: str) -> str:
    text = re.sub(r"\{.*?\}", " ", text, flags=re.S)
    text = re.sub(r"\(\*.*?\*\)", " ", text, flags=re.S)
    text = re.sub(r"//.*?$", " ", text, flags=re.M)
    return text


def find_forbidden_in_uses(text: str) -> list[str]:
    hits: list[str] = []
    cleaned = strip_comments(text)
    for block in USES_BLOCK_RE.findall(cleaned):
        for match in UNIT_TOKEN_RE.finditer(block):
            unit = match.group(1)
            if unit not in hits:
                hits.append(unit)
    return hits


def collect_files(root: Path, globs: tuple[str, ...]) -> list[Path]:
    files: list[Path] = []
    for pattern in globs:
        files.extend(sorted(root.glob(pattern)))
    # de-dupe while preserving order
    seen: set[Path] = set()
    unique: list[Path] = []
    for path in files:
        if path not in seen and path.is_file():
            seen.add(path)
            unique.append(path)
    return unique


def scan_paths(root: Path, paths: list[Path]) -> list[dict]:
    findings: list[dict] = []
    for path in paths:
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError as exc:
            findings.append(
                {
                    "path": str(path.relative_to(root)),
                    "units": [],
                    "error": str(exc),
                }
            )
            continue
        units = find_forbidden_in_uses(text)
        if units:
            findings.append(
                {
                    "path": str(path.relative_to(root)),
                    "units": units,
                }
            )
    return findings


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=None,
        help="core/ root (default: ../../../ from this file)",
    )
    parser.add_argument("--json-file", type=Path, default=None)
    parser.add_argument("--summary-line", action="store_true")
    parser.add_argument(
        "--fail-tests",
        action="store_true",
        help="Also fail when test/example/benchmark trees use forbidden RTL units",
    )
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)

    if args.self_test:
        sample_bad = "unit u;\ninterface\nuses SysUtils, Math;\n"
        sample_ok = "unit u;\ninterface\nuses nextpas.core.math.scalar;\n"
        sample_member = "implementation\nbegin Result := Math.FMod(1, 2); end.\n"
        assert find_forbidden_in_uses(sample_bad) == ["SysUtils", "Math"]
        assert find_forbidden_in_uses(sample_ok) == []
        # Member access is not a uses violation; production still must not call Math.*
        # but uses-clause isolation is the gate this checker owns.
        assert find_forbidden_in_uses(sample_member) == []
        print(f"{SUMMARY_PREFIX} self-test OK")
        return 0

    script_dir = Path(__file__).resolve().parent
    root = (args.root or (script_dir / "../../..")).resolve()

    prod_findings = scan_paths(root, collect_files(root, PRODUCTION_GLOBS))
    test_findings = scan_paths(root, collect_files(root, TEST_GLOBS))

    report = {
        "root": str(root),
        "forbidden_units": list(FORBIDDEN_UNITS),
        "production_violations": prod_findings,
        "test_violations": test_findings,
        "production_count": len(prod_findings),
        "test_count": len(test_findings),
    }

    if args.json_file:
        args.json_file.parent.mkdir(parents=True, exist_ok=True)
        args.json_file.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    if prod_findings:
        print("FAIL: production math/simd RTL isolation violations:", file=sys.stderr)
        for item in prod_findings:
            print(f"  {item['path']}: {', '.join(item.get('units', []))}", file=sys.stderr)
    else:
        print("OK: production math/simd has no forbidden FPC RTL uses-clause units")

    if test_findings:
        level = "FAIL" if args.fail_tests else "WARN"
        print(
            f"{level}: test/example/benchmark RTL uses ({len(test_findings)} files):",
            file=sys.stderr if args.fail_tests else sys.stdout,
        )
        for item in test_findings[:40]:
            print(f"  {item['path']}: {', '.join(item.get('units', []))}")
        if len(test_findings) > 40:
            print(f"  ... and {len(test_findings) - 40} more")
    else:
        print("OK: test/example/benchmark trees have no forbidden RTL uses-clause units")

    if args.summary_line:
        status = "PASS"
        if prod_findings or (args.fail_tests and test_findings):
            status = "FAIL"
        print(
            f"{SUMMARY_PREFIX} status={status} "
            f"production={len(prod_findings)} test={len(test_findings)} "
            f"fail_tests={int(args.fail_tests)}"
        )

    if prod_findings:
        return 1
    if args.fail_tests and test_findings:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

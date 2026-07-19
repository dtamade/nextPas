#!/usr/bin/env python3
"""
Generate nextpas.core.text.unicode.sbp.inc from SentenceBreakProperty.txt (Unicode 16.0).

Usage:
  python3 core/scripts/gen_unicode_sbp.py --version 16.0.0 --output-dir core/src
  python3 core/scripts/gen_unicode_sbp.py --src /path/SentenceBreakProperty.txt --output-dir core/src
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import urllib.request
from typing import Dict, List, Tuple

DEFAULT_VERSION = "16.0.0"
UCD_BASE = "https://www.unicode.org/Public/{version}/ucd/"

# Ordinals MUST match TSentenceBreakProperty in types.pas
SBP_VALUES = [
    "Other",  # 0
    "CR",  # 1
    "LF",  # 2
    "Extend",  # 3
    "Sep",  # 4
    "Format",  # 5
    "Sp",  # 6
    "Lower",  # 7
    "Upper",  # 8
    "OLetter",  # 9
    "Numeric",  # 10
    "ATerm",  # 11
    "SContinue",  # 12
    "STerm",  # 13
    "Close",  # 14
]
SBP_NAME_TO_ORDINAL = {name: idx for idx, name in enumerate(SBP_VALUES)}


def download_ucd(version: str, filename: str) -> str:
    url = UCD_BASE.format(version=version) + filename
    print(f"  Downloading {url} ...", file=sys.stderr)
    try:
        result = subprocess.run(
            ["curl", "-fsSL", "--retry", "3", "--retry-delay", "1", url],
            check=False,
            capture_output=True,
        )
        if result.returncode == 0 and result.stdout:
            return result.stdout.decode("utf-8", errors="replace")
        print(f"  curl failed (rc={result.returncode}), falling back to urllib", file=sys.stderr)
    except FileNotFoundError:
        pass
    try:
        with urllib.request.urlopen(url, timeout=120) as resp:
            return resp.read().decode("utf-8", errors="replace")
    except Exception as e:  # noqa: BLE001
        print(f"  ERROR: {e}", file=sys.stderr)
        sys.exit(1)


def parse_ranges(text: str) -> List[Tuple[int, int, str]]:
    ranges: List[Tuple[int, int, str]] = []
    for raw_line in text.splitlines():
        line = raw_line.split("#", 1)[0].strip()
        if not line:
            continue
        parts = line.split(";")
        if len(parts) < 2:
            continue
        range_str = parts[0].strip()
        value = parts[1].strip()
        if ".." in range_str:
            lo, hi = range_str.split("..")
            ranges.append((int(lo, 16), int(hi, 16), value))
        else:
            cp = int(range_str, 16)
            ranges.append((cp, cp, value))
    return ranges


def parse_sentence_break_property(text: str) -> Dict[int, int]:
    sbp: Dict[int, int] = {}
    unknown = set()
    for lo, hi, value in parse_ranges(text):
        if value not in SBP_NAME_TO_ORDINAL:
            unknown.add(value)
            continue
        ordinal = SBP_NAME_TO_ORDINAL[value]
        for cp in range(lo, hi + 1):
            sbp[cp] = ordinal
    if unknown:
        print(f"  WARNING: unknown SBP values skipped: {sorted(unknown)}", file=sys.stderr)
    return sbp


def build_tables(sbp: Dict[int, int]) -> Tuple[List[List[int]], List[Tuple[int, int, int]]]:
    bmp_table = [[0] * 256 for _ in range(256)]
    for cp in range(0x10000):
        bmp_table[(cp >> 8) & 0xFF][cp & 0xFF] = sbp.get(cp, 0)

    smp_ranges: List[Tuple[int, int, int]] = []
    range_start = 0x10000
    current_val = sbp.get(range_start, 0)
    for cp in range(0x10001, 0x10FFFF + 1):
        val = sbp.get(cp, 0)
        if val != current_val:
            smp_ranges.append((range_start, cp - 1, current_val))
            range_start = cp
            current_val = val
    smp_ranges.append((range_start, 0x10FFFF, current_val))
    return bmp_table, smp_ranges


def pascal_stage2_table(table: List[List[int]], name: str) -> str:
    lines = [f"  {name}: array[0..255, 0..255] of Byte = ("]
    for hi in range(256):
        row = ", ".join(str(v) for v in table[hi])
        sep = "," if hi < 255 else ""
        lines.append(f"    // hi=${hi:02X}")
        lines.append(f"    ({row}){sep}")
    lines.append("  );")
    return "\n".join(lines)


def pascal_ranges_list(ranges: List[Tuple[int, int, int]], name: str) -> str:
    if not ranges:
        return f"  {name}: array[0..0] of TCodepointRange3 = ( (Lo: 0; Hi: 0; Value: 0) );"
    lines = [f"  {name}: array[0..{len(ranges)-1}] of TCodepointRange3 = ("]
    for i, (lo, hi, val) in enumerate(ranges):
        sep = "," if i < len(ranges) - 1 else ""
        lines.append(f"    (Lo: ${lo:06X}; Hi: ${hi:06X}; Value: {val}){sep}")
    lines.append("  );")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate Sentence_Break property tables")
    parser.add_argument("--version", default=DEFAULT_VERSION)
    parser.add_argument("--output-dir", default="core/src")
    parser.add_argument("--src", default=None, help="Local SentenceBreakProperty.txt")
    args = parser.parse_args()

    if args.src:
        with open(args.src, "r", encoding="utf-8", errors="replace") as f:
            text = f.read()
    else:
        text = download_ucd(args.version, "auxiliary/SentenceBreakProperty.txt")

    sbp = parse_sentence_break_property(text)
    bmp, smp = build_tables(sbp)

    ordinal_comment = ", ".join(f"{i}={n}" for i, n in enumerate(SBP_VALUES))
    out = f"""// {{Auto-generated by gen_unicode_sbp.py — Unicode {args.version}}}
// Sentence_Break property data from auxiliary/SentenceBreakProperty.txt.
//
// SBP values (TSentenceBreakProperty ordinal):
//   {ordinal_comment}

const
  // ── BMP SBP Lookup (stage-2: [high][low] → SBP ordinal) ──
{pascal_stage2_table(bmp, "SBP_BMP_TABLE")}

  // ── SMP SBP Ranges (0x10000-0x10FFFF) ──
  SBP_SMP_RANGES_COUNT = {len(smp)};
{pascal_ranges_list(smp, "SBP_SMP_RANGES")}
"""
    os.makedirs(args.output_dir, exist_ok=True)
    path = os.path.join(args.output_dir, "nextpas.core.text.unicode.sbp.inc")
    with open(path, "w", encoding="utf-8") as f:
        f.write(out)
    print(
        f"Wrote {path} ({len(out)} bytes, {len(sbp)} assigned codepoints, {len(smp)} SMP ranges)",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()

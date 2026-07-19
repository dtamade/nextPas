#!/usr/bin/env python3
"""
Generate nextpas.core.text.unicode.lbp.inc from LineBreak.txt (Unicode 16.0).

Usage:
  python3 core/scripts/gen_unicode_lbp.py --version 16.0.0 --output-dir core/src
  python3 core/scripts/gen_unicode_lbp.py --src /path/LineBreak.txt --output-dir core/src

Ordinals MUST match TLineBreakClass in types.pas (when wired).
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

# Index 0 = XX. Indices 1..33 match classic pair-table order (OP..CB).
LBP_VALUES = [
    "XX",  # 0
    "OP",
    "CL",
    "CP",
    "QU",
    "GL",
    "NS",
    "EX",
    "SY",
    "IS",
    "PR",
    "PO",
    "NU",
    "AL",
    "HL",
    "ID",
    "IN",
    "HY",
    "BA",
    "BB",
    "B2",
    "ZW",
    "CM",
    "WJ",
    "H2",
    "H3",
    "JL",
    "JV",
    "JT",
    "RI",
    "EB",
    "EM",
    "ZWJ",
    "CB",  # 33
    "AI",
    "BK",
    "CJ",
    "CR",
    "LF",
    "NL",
    "SA",
    "SG",
    "SP",
    "AK",
    "AP",
    "AS",
    "VF",
    "VI",  # 47
]
LBP_NAME_TO_ORDINAL = {name: idx for idx, name in enumerate(LBP_VALUES)}


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


def parse_line_break(text: str) -> Dict[int, int]:
    lbp: Dict[int, int] = {}
    unknown = set()
    for lo, hi, value in parse_ranges(text):
        if value not in LBP_NAME_TO_ORDINAL:
            unknown.add(value)
            continue
        ordinal = LBP_NAME_TO_ORDINAL[value]
        for cp in range(lo, hi + 1):
            lbp[cp] = ordinal
    if unknown:
        print(f"  WARNING: unknown LBP values skipped: {sorted(unknown)}", file=sys.stderr)
    return lbp


def build_tables(lbp: Dict[int, int]) -> Tuple[List[List[int]], List[Tuple[int, int, int]]]:
    bmp_table = [[0] * 256 for _ in range(256)]
    for cp in range(0x10000):
        bmp_table[(cp >> 8) & 0xFF][cp & 0xFF] = lbp.get(cp, 0)

    smp_ranges: List[Tuple[int, int, int]] = []
    range_start = 0x10000
    current_val = lbp.get(range_start, 0)
    for cp in range(0x10001, 0x10FFFF + 1):
        val = lbp.get(cp, 0)
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
    parser = argparse.ArgumentParser(description="Generate Line_Break property tables")
    parser.add_argument("--version", default=DEFAULT_VERSION)
    parser.add_argument("--output-dir", default="core/src")
    parser.add_argument("--src", default=None, help="Local LineBreak.txt")
    args = parser.parse_args()

    if args.src:
        with open(args.src, "r", encoding="utf-8", errors="replace") as f:
            text = f.read()
    else:
        text = download_ucd(args.version, "LineBreak.txt")

    lbp = parse_line_break(text)
    bmp, smp = build_tables(lbp)

    ordinal_comment = ", ".join(f"{i}={n}" for i, n in enumerate(LBP_VALUES))
    out = f"""// {{Auto-generated by gen_unicode_lbp.py — Unicode {args.version}}}
// Line_Break property data from LineBreak.txt.
//
// LBP values (TLineBreakClass ordinal):
//   {ordinal_comment}

const
  // ── BMP LBP Lookup (stage-2: [high][low] → LBP ordinal) ──
{pascal_stage2_table(bmp, "LBP_BMP_TABLE")}

  // ── SMP LBP Ranges (0x10000-0x10FFFF) ──
  LBP_SMP_RANGES_COUNT = {len(smp)};
{pascal_ranges_list(smp, "LBP_SMP_RANGES")}
"""
    os.makedirs(args.output_dir, exist_ok=True)
    path = os.path.join(args.output_dir, "nextpas.core.text.unicode.lbp.inc")
    with open(path, "w", encoding="utf-8") as f:
        f.write(out)
    print(
        f"Wrote {path} ({len(out)} bytes, {len(lbp)} assigned codepoints, {len(smp)} SMP ranges)",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Generate nextpas.core.text.unicode.bcp.inc from DerivedBidiClass.txt (Unicode 16.0).

Usage:
  python3 core/scripts/gen_unicode_bc.py --version 16.0.0 --output-dir core/src
  python3 core/scripts/gen_unicode_bc.py --src /path/DerivedBidiClass.txt --output-dir core/src

Ordinals MUST match TBidiClass in types.pas.
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

# Ordinals MUST match TBidiClass in types.pas
BC_VALUES = [
    "L",  # 0
    "R",  # 1
    "EN",  # 2
    "ES",  # 3
    "ET",  # 4
    "AN",  # 5
    "CS",  # 6
    "B",  # 7
    "S",  # 8
    "WS",  # 9
    "ON",  # 10
    "BN",  # 11
    "NSM",  # 12
    "AL",  # 13
    "LRE",  # 14
    "LRO",  # 15
    "RLE",  # 16
    "RLO",  # 17
    "PDF",  # 18
    "LRI",  # 19
    "RLI",  # 20
    "FSI",  # 21
    "PDI",  # 22
]
BC_NAME_TO_ORDINAL = {name: idx for idx, name in enumerate(BC_VALUES)}
DEFAULT_ORDINAL = BC_NAME_TO_ORDINAL["L"]


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


def parse_bidi_class(text: str) -> Dict[int, int]:
    bc: Dict[int, int] = {}
    unknown = set()
    for lo, hi, value in parse_ranges(text):
        if value not in BC_NAME_TO_ORDINAL:
            unknown.add(value)
            continue
        ordinal = BC_NAME_TO_ORDINAL[value]
        for cp in range(lo, hi + 1):
            bc[cp] = ordinal
    if unknown:
        print(f"  WARNING: unknown BC values skipped: {sorted(unknown)}", file=sys.stderr)
    return bc


def build_tables(bc: Dict[int, int]) -> Tuple[List[List[int]], List[Tuple[int, int, int]]]:
    bmp_table = [[DEFAULT_ORDINAL] * 256 for _ in range(256)]
    for cp in range(0x10000):
        bmp_table[(cp >> 8) & 0xFF][cp & 0xFF] = bc.get(cp, DEFAULT_ORDINAL)

    smp_ranges: List[Tuple[int, int, int]] = []
    range_start = 0x10000
    current_val = bc.get(range_start, DEFAULT_ORDINAL)
    for cp in range(0x10001, 0x10FFFF + 1):
        val = bc.get(cp, DEFAULT_ORDINAL)
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
    parser = argparse.ArgumentParser(description="Generate Bidi_Class property tables")
    parser.add_argument("--version", default=DEFAULT_VERSION)
    parser.add_argument("--output-dir", default="core/src")
    parser.add_argument("--src", default=None, help="Local DerivedBidiClass.txt")
    args = parser.parse_args()

    if args.src:
        with open(args.src, "r", encoding="utf-8", errors="replace") as f:
            text = f.read()
    else:
        text = download_ucd(args.version, "extracted/DerivedBidiClass.txt")

    bc = parse_bidi_class(text)
    bmp, smp = build_tables(bc)

    ordinal_comment = ", ".join(f"{i}={n}" for i, n in enumerate(BC_VALUES))
    out = f"""// {{Auto-generated by gen_unicode_bc.py — Unicode {args.version}}}
// Bidi_Class property data from extracted/DerivedBidiClass.txt.
// Default (unlisted) = L (ordinal {DEFAULT_ORDINAL}).
//
// BC values (TBidiClass ordinal):
//   {ordinal_comment}

const
  // ── BMP Bidi_Class Lookup (stage-2: [high][low] → BC ordinal) ──
{pascal_stage2_table(bmp, "BCP_BMP_TABLE")}

  // ── SMP Bidi_Class Ranges (0x10000-0x10FFFF) ──
  BCP_SMP_RANGES_COUNT = {len(smp)};
{pascal_ranges_list(smp, "BCP_SMP_RANGES")}
"""
    os.makedirs(args.output_dir, exist_ok=True)
    path = os.path.join(args.output_dir, "nextpas.core.text.unicode.bcp.inc")
    with open(path, "w", encoding="utf-8") as f:
        f.write(out)
    print(
        f"Wrote {path} ({len(out)} bytes, {len(bc)} assigned codepoints, {len(smp)} SMP ranges)",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()

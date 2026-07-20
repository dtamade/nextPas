#!/usr/bin/env python3
"""Generate nextpas.core.text.unicode.collate.inc from UCA allkeys.txt (full multi-CE).

Unicode Collation Algorithm data (DUCET), version-pinned.

Output layout:
  - CE_POOL: packed UInt64 CEs
      bits 0..15  primary
      bits 16..31 secondary
      bits 32..47 tertiary
      bit  48     variable (from [*....])
  - COLLATE_BMP_INDEX[hi][lo] -> 0 = not explicit (use implicit);
      else (offset << 8) | length  into CE_POOL
  - COLLATE_SMP_ENTRIES: sparse (cp, offset, length) sorted by cp
  - Contractions: headers + rest codepoint pool

Usage:
  python3 core/scripts/gen_unicode_collate.py --version 16.0.0 --output-dir core/src
"""

from __future__ import annotations

import argparse
import re
import sys
import urllib.request
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

CE = Tuple[int, int, int, bool]  # primary, secondary, tertiary, variable
Entry = List[CE]

CE_RE = re.compile(
    r"\[([.*])([0-9A-Fa-f]{4})\.([0-9A-Fa-f]{4})\.([0-9A-Fa-f]{4})\]"
)


def download_allkeys(version: str) -> str:
    # Prefer versioned UCA tree; fall back to latest.
    urls = [
        f"https://www.unicode.org/Public/UCA/{version}/allkeys.txt",
        "https://www.unicode.org/Public/UCA/latest/allkeys.txt",
    ]
    last_err: Optional[Exception] = None
    for url in urls:
        try:
            with urllib.request.urlopen(url, timeout=120) as resp:
                return resp.read().decode("utf-8", errors="replace")
        except Exception as exc:  # noqa: BLE001
            last_err = exc
    raise RuntimeError(f"download allkeys failed: {last_err}")


def parse_ces(ces_str: str) -> Entry:
    out: Entry = []
    for m in CE_RE.finditer(ces_str):
        variable = m.group(1) == "*"
        primary = int(m.group(2), 16)
        secondary = int(m.group(3), 16)
        tertiary = int(m.group(4), 16)
        out.append((primary, secondary, tertiary, variable))
    return out


def parse_allkeys(text: str) -> Tuple[
    Dict[int, Entry],
    List[Tuple[List[int], Entry]],
    List[Tuple[int, int, int]],
]:
    """Return (single_cp_map, contractions, implicit_ranges).

    implicit_ranges: (lo, hi, base_primary) from @implicitweights.
    """
    singles: Dict[int, Entry] = {}
    contractions: List[Tuple[List[int], Entry]] = []
    implicit_ranges: List[Tuple[int, int, int]] = []

    for raw in text.splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if line.startswith("@implicitweights"):
            m = re.match(
                r"@implicitweights\s+([0-9A-Fa-f]+)\.\.([0-9A-Fa-f]+);\s*([0-9A-Fa-f]+)",
                line,
            )
            if m:
                lo = int(m.group(1), 16)
                hi = int(m.group(2), 16)
                base = int(m.group(3), 16)
                implicit_ranges.append((lo, hi, base))
            continue
        if line.startswith("@"):
            continue
        if ";" not in line:
            continue
        left, right = line.split(";", 1)
        cps = [int(x, 16) for x in left.strip().split()]
        if not cps:
            continue
        ces = parse_ces(right)
        if not ces:
            continue
        if len(cps) == 1:
            singles[cps[0]] = ces
        else:
            contractions.append((cps, ces))

    return singles, contractions, implicit_ranges


def pack_ce(primary: int, secondary: int, tertiary: int, variable: bool) -> int:
    if primary > 0xFFFF or secondary > 0xFFFF or tertiary > 0xFFFF:
        raise ValueError(
            f"CE component overflow: {primary:x}.{secondary:x}.{tertiary:x}"
        )
    v = primary | (secondary << 16) | (tertiary << 32)
    if variable:
        v |= 1 << 48
    return v


def build_pool(
    singles: Dict[int, Entry],
    contractions: List[Tuple[List[int], Entry]],
) -> Tuple[List[int], Dict[int, Tuple[int, int]], List[Tuple[List[int], int, int]]]:
    """Dedup CE sequences into a pool.

    Returns:
      pool: list of packed UInt64
      single_index: cp -> (offset, length)
      contraction_index: list of (cps, offset, length)
    """
    pool: List[int] = []
    seq_cache: Dict[Tuple[int, ...], Tuple[int, int]] = {}

    def add_seq(entry: Entry) -> Tuple[int, int]:
        key = tuple(pack_ce(*ce) for ce in entry)
        hit = seq_cache.get(key)
        if hit is not None:
            return hit
        offset = len(pool)
        pool.extend(key)
        length = len(key)
        seq_cache[key] = (offset, length)
        return offset, length

    single_index: Dict[int, Tuple[int, int]] = {}
    for cp, entry in singles.items():
        single_index[cp] = add_seq(entry)

    contraction_index: List[Tuple[List[int], int, int]] = []
    for cps, entry in contractions:
        off, ln = add_seq(entry)
        contraction_index.append((cps, off, ln))

    # Longest match first within same first codepoint.
    contraction_index.sort(key=lambda t: (t[0][0], -len(t[0]), t[0][1:]))
    return pool, single_index, contraction_index


def pascal_u64_array(name: str, values: Sequence[int], cols: int = 4) -> str:
    lines = [f"  {name}: array[0..{len(values) - 1}] of UInt64 = ("]
    row: List[str] = []
    for i, v in enumerate(values):
        row.append(f"${v:016X}")
        if len(row) == cols or i == len(values) - 1:
            comma = "," if i < len(values) - 1 else ""
            lines.append("    " + ", ".join(row) + comma)
            row = []
    lines.append("  );")
    return "\n".join(lines)


def pascal_u32_array(name: str, values: Sequence[int], cols: int = 8) -> str:
    if not values:
        return f"  {name}: array[0..0] of UInt32 = (0);  // empty placeholder"
    lines = [f"  {name}: array[0..{len(values) - 1}] of UInt32 = ("]
    row: List[str] = []
    for i, v in enumerate(values):
        row.append(f"${v:08X}")
        if len(row) == cols or i == len(values) - 1:
            comma = "," if i < len(values) - 1 else ""
            lines.append("    " + ", ".join(row) + comma)
            row = []
    lines.append("  );")
    return "\n".join(lines)


def build_bmp_index(single_index: Dict[int, Tuple[int, int]]) -> List[List[int]]:
    table = [[0] * 256 for _ in range(256)]
    for cp, (off, ln) in single_index.items():
        if cp > 0xFFFF:
            continue
        if ln > 0xFF:
            raise ValueError(f"CE length {ln} > 255 at U+{cp:04X}")
        if off > 0xFFFFFF:
            raise ValueError(f"CE offset {off} too large at U+{cp:04X}")
        table[cp >> 8][cp & 0xFF] = (off << 8) | ln
    return table


def pascal_bmp_index(table: List[List[int]]) -> str:
    lines = ["  COLLATE_BMP_INDEX: array[0..255, 0..255] of UInt32 = ("]
    for hi in range(256):
        lines.append(f"    // hi=${hi:02X}")
        row = table[hi]
        # emit 16 per line
        for base in range(0, 256, 16):
            chunk = row[base : base + 16]
            body = ", ".join(f"${v:08X}" for v in chunk)
            if hi == 255 and base + 16 >= 256:
                lines.append(f"    ({body})")
            elif base + 16 >= 256:
                lines.append(f"    ({body}),")
            else:
                lines.append(f"    ({body},")
        if hi != 255 and False:
            pass
    lines.append("  );")
    # Fix nested array syntax: FPC wants ((...), (...))
    # Rebuild properly.
    lines = ["  COLLATE_BMP_INDEX: array[0..255, 0..255] of UInt32 = ("]
    for hi in range(256):
        row = table[hi]
        parts = [f"${v:08X}" for v in row]
        # group
        grouped: List[str] = []
        for base in range(0, 256, 16):
            grouped.append(", ".join(parts[base : base + 16]))
        inner = ",\n     ".join(grouped)
        comma = "," if hi < 255 else ""
        lines.append(f"    ({inner}){comma}  // hi=${hi:02X}")
    lines.append("  );")
    return "\n".join(lines)


def build_smp_entries(single_index: Dict[int, Tuple[int, int]]) -> List[Tuple[int, int, int]]:
    items = []
    for cp, (off, ln) in sorted(single_index.items()):
        if cp <= 0xFFFF:
            continue
        items.append((cp, off, ln))
    return items


def emit_inc(
    version: str,
    pool: List[int],
    single_index: Dict[int, Tuple[int, int]],
    contraction_index: List[Tuple[List[int], int, int]],
    implicit_ranges: List[Tuple[int, int, int]],
) -> str:
    bmp = build_bmp_index(single_index)
    smp = build_smp_entries(single_index)

    # Contractions: rest pool + headers
    rest_pool: List[int] = []
    # header: FirstCp, RestLen, CeOffset, CeLen, RestOffset
    # pack as parallel arrays for simpler Pascal
    c_first: List[int] = []
    c_rest_len: List[int] = []
    c_ce_off: List[int] = []
    c_ce_len: List[int] = []
    c_rest_off: List[int] = []
    for cps, off, ln in contraction_index:
        rest = cps[1:]
        rest_off = len(rest_pool)
        rest_pool.extend(rest)
        c_first.append(cps[0])
        c_rest_len.append(len(rest))
        c_ce_off.append(off)
        c_ce_len.append(ln)
        c_rest_off.append(rest_off if rest else 0)

    # Implicit ranges arrays
    imp_lo = [r[0] for r in implicit_ranges]
    imp_hi = [r[1] for r in implicit_ranges]
    imp_base = [r[2] for r in implicit_ranges]

    max_sec = 0
    max_ter = 0
    max_pri = 0
    max_len = 0
    for v in pool:
        pri = v & 0xFFFF
        sec = (v >> 16) & 0xFFFF
        ter = (v >> 32) & 0xFFFF
        max_pri = max(max_pri, pri)
        max_sec = max(max_sec, sec)
        max_ter = max(max_ter, ter)
    for _, (_, ln) in single_index.items():
        max_len = max(max_len, ln)
    for _, _, ln in contraction_index:
        max_len = max(max_len, ln)

    header = f"""// {{Auto-generated by gen_unicode_collate.py — UCA {version}}}
// Full DUCET multi-CE + contractions + variable flags.
//
// CE pack (UInt64):
//   bits  0..15  primary
//   bits 16..31  secondary
//   bits 32..47  tertiary
//   bit  48      variable (from [*p.s.t])
//
// BMP index: 0 = no explicit mapping (runtime implicit weights);
//            else (pool_offset << 8) | ce_count
// Stats: pool={len(pool)} singles={len(single_index)} contractions={len(contraction_index)}
//        max_pri=${max_pri:04X} max_sec=${max_sec:04X} max_ter=${max_ter:04X} max_ce_len={max_len}

const
  COLLATE_CE_POOL_COUNT = {len(pool)};
  COLLATE_SMP_COUNT = {max(len(smp), 1)};
  COLLATE_CONTRACTION_COUNT = {max(len(contraction_index), 1)};
  COLLATE_CONTRACTION_REST_COUNT = {max(len(rest_pool), 1)};
  COLLATE_IMPLICIT_RANGE_COUNT = {max(len(implicit_ranges), 1)};
"""

    # Always emit at least one element for empty arrays so Pascal const arrays compile.
    pool_vals = pool if pool else [0]
    rest_vals = rest_pool if rest_pool else [0]
    if not contraction_index:
        c_first, c_rest_len, c_ce_off, c_ce_len, c_rest_off = [0], [0], [0], [0], [0]
    if not smp:
        smp_cp, smp_off, smp_len = [0], [0], [0]
    else:
        smp_cp = [t[0] for t in smp]
        smp_off = [t[1] for t in smp]
        smp_len = [t[2] for t in smp]
    if not implicit_ranges:
        imp_lo, imp_hi, imp_base = [0], [0], [0]

    body = []
    body.append(pascal_u64_array("COLLATE_CE_POOL", pool_vals))
    body.append("")
    body.append(pascal_bmp_index(bmp))
    body.append("")
    body.append(pascal_u32_array("COLLATE_SMP_CP", smp_cp))
    body.append(pascal_u32_array("COLLATE_SMP_OFF", smp_off))
    body.append(pascal_u32_array("COLLATE_SMP_LEN", smp_len))
    body.append("")
    body.append(pascal_u32_array("COLLATE_CTR_FIRST", c_first))
    body.append(pascal_u32_array("COLLATE_CTR_REST_LEN", c_rest_len))
    body.append(pascal_u32_array("COLLATE_CTR_CE_OFF", c_ce_off))
    body.append(pascal_u32_array("COLLATE_CTR_CE_LEN", c_ce_len))
    body.append(pascal_u32_array("COLLATE_CTR_REST_OFF", c_rest_off))
    body.append(pascal_u32_array("COLLATE_CTR_REST", rest_vals))
    body.append("")
    body.append(pascal_u32_array("COLLATE_IMP_LO", imp_lo))
    body.append(pascal_u32_array("COLLATE_IMP_HI", imp_hi))
    body.append(pascal_u32_array("COLLATE_IMP_BASE", imp_base))

    return header + "\n" + "\n".join(body) + "\n"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", default="16.0.0")
    ap.add_argument("--output-dir", default="core/src")
    ap.add_argument("--allkeys", default="", help="Local allkeys.txt (skip download)")
    args = ap.parse_args()

    if args.allkeys:
        text = Path(args.allkeys).read_text(encoding="utf-8", errors="replace")
    else:
        print(f"Downloading UCA {args.version} allkeys.txt ...", file=sys.stderr)
        text = download_allkeys(args.version)

    singles, contractions, implicit = parse_allkeys(text)
    pool, single_index, contraction_index = build_pool(singles, contractions)
    out = emit_inc(args.version, pool, single_index, contraction_index, implicit)

    out_path = Path(args.output_dir) / "nextpas.core.text.unicode.collate.inc"
    out_path.write_text(out, encoding="utf-8")
    print(
        f"Wrote {out_path} pool={len(pool)} singles={len(single_index)} "
        f"contractions={len(contraction_index)} implicit_ranges={len(implicit)}",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()

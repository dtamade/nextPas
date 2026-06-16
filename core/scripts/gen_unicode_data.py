#!/usr/bin/env python3
"""
Unicode 16.0 UCD → Pascal .inc lookup table generator.

Downloads Unicode Character Database files from unicode.org and produces
compact Pascal include files for nextpas.core.text.unicode modules.

Usage:
    python3 gen_unicode_data.py [--version 16.0.0] [--output-dir ../src]

Output:
    - nextpas.core.text.unicode.data.inc
    - nextpas.core.text.unicode.props.inc
    - nextpas.core.text.unicode.casefold.inc
    - nextpas.core.text.unicode.normalize.inc
"""

import urllib.error
import urllib.request
import argparse
import os
import sys
from dataclasses import dataclass
from typing import Dict, List, Optional, Set, Tuple

# ─── Unicode version ───────────────────────────────────────────────
DEFAULT_VERSION = "16.0.0"
UCD_BASE = "https://www.unicode.org/Public/{version}/ucd/"
HANGUL_SBASE = 0xAC00
HANGUL_LBASE = 0x1100
HANGUL_VBASE = 0x1161
HANGUL_TBASE = 0x11A7
HANGUL_LCOUNT = 19
HANGUL_VCOUNT = 21
HANGUL_TCOUNT = 28
HANGUL_NCOUNT = HANGUL_VCOUNT * HANGUL_TCOUNT
HANGUL_SCOUNT = HANGUL_LCOUNT * HANGUL_NCOUNT
MAX_DECOMP_MAP_LEN = 18

# ─── General Category constants ────────────────────────────────────
CAT_NAMES = {
    "Lu": "gcuUppercaseLetter",
    "Ll": "gcuLowercaseLetter",
    "Lt": "gcuTitlecaseLetter",
    "Lm": "gcuModifierLetter",
    "Lo": "gcuOtherLetter",
    "Mn": "gcuNonspacingMark",
    "Mc": "gcuSpacingMark",
    "Me": "gcuEnclosingMark",
    "Nd": "gcuDecimalNumber",
    "Nl": "gcuLetterNumber",
    "No": "gcuOtherNumber",
    "Pc": "gcuConnectorPunctuation",
    "Pd": "gcuDashPunctuation",
    "Ps": "gcuOpenPunctuation",
    "Pe": "gcuClosePunctuation",
    "Pi": "gcuInitialPunctuation",
    "Pf": "gcuFinalPunctuation",
    "Po": "gcuOtherPunctuation",
    "Sm": "gcuMathSymbol",
    "Sc": "gcuCurrencySymbol",
    "Sk": "gcuModifierSymbol",
    "So": "gcuOtherSymbol",
    "Zs": "gcuSpaceSeparator",
    "Zl": "gcuLineSeparator",
    "Zp": "gcuParagraphSeparator",
    "Cc": "gcuControl",
    "Cf": "gcuFormat",
    "Cs": "gcuSurrogate",
    "Co": "gcuPrivateUse",
    "Cn": "gcuUnassigned",
}

CAT_CODES = list(CAT_NAMES.keys())
CAT_ENUM_VALUES = {code: idx for idx, code in enumerate(CAT_CODES)}

# ─── Derived binary properties ─────────────────────────────────────
BINARY_PROPS = [
    "Alphabetic",
    "Lowercase",
    "Uppercase",
    "Cased",
    "Case_Ignorable",
    "ID_Start",
    "ID_Continue",
    "XID_Start",
    "XID_Continue",
    "White_Space",
    "Grapheme_Base",
    "Grapheme_Extend",
    "Math",
    "Emoji",
    "Emoji_Presentation",
    "Emoji_Modifier",
    "Emoji_Modifier_Base",
    "Emoji_Component",
    "Default_Ignorable_Code_Point",
    "Deprecated",
    "Soft_Dotted",
]


@dataclass
class CodepointData:
    cp: int
    name: str
    category: str
    combining: int
    bidi_class: str
    decomposition: str
    simple_upper: int = -1
    simple_lower: int = -1
    simple_title: int = -1


@dataclass
class CaseFoldData:
    cp: int
    status: str  # C, F, S, T, I
    mapping: List[int]


def download_ucd(version: str, filename: str) -> str:
    """Download a UCD file, return its text content."""
    url = UCD_BASE.format(version=version) + filename
    print(f"  Downloading {url} ...", file=sys.stderr)
    try:
        with urllib.request.urlopen(url, timeout=30) as resp:
            data = resp.read().decode("utf-8", errors="replace")
        return data
    except urllib.error.HTTPError as e:
        print(f"  ERROR: HTTP {e.code} fetching {url}", file=sys.stderr)
        sys.exit(1)


def parse_unicode_data(text: str) -> Dict[int, CodepointData]:
    """Parse UnicodeData.txt into codepoint records."""
    records: Dict[int, CodepointData] = {}
    pending_range: Optional[CodepointData] = None

    for line in text.splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        fields = line.split(";")
        if len(fields) < 15:
            continue
        cp = int(fields[0], 16)
        name = fields[1]
        category = fields[2]
        combining = int(fields[3])
        bidi_class = fields[4]
        decomposition = fields[5]
        record = CodepointData(
            cp=cp,
            name=name,
            category=category,
            combining=combining,
            bidi_class=bidi_class,
            decomposition=decomposition,
        )

        if name.startswith("<") and name.endswith(">") and "," in name:
            range_name, marker = name[1:-1].rsplit(",", 1)
            range_name = range_name.strip()
            marker = marker.strip()
            if marker == "First":
                pending_range = record
                records[cp] = record
                continue
            if marker == "Last" and pending_range is not None:
                pending_name, _ = pending_range.name[1:-1].rsplit(",", 1)
                if pending_name.strip() != range_name:
                    raise ValueError(
                        f"UnicodeData range mismatch: expected {pending_name.strip()}, got {range_name}"
                    )
                for range_cp in range(pending_range.cp, cp + 1):
                    records[range_cp] = CodepointData(
                        cp=range_cp,
                        name=pending_range.name,
                        category=pending_range.category,
                        combining=pending_range.combining,
                        bidi_class=pending_range.bidi_class,
                        decomposition=pending_range.decomposition,
                    )
                pending_range = None
                continue

        records[cp] = record

    if pending_range is not None:
        raise ValueError(f"Unclosed UnicodeData range starting at U+{pending_range.cp:04X}")

    return records


def parse_ranges(text: str) -> List[Tuple[int, int, str]]:
    """Parse a UCD property file (like DerivedCoreProperties.txt) into range+value list."""
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


def parse_case_folding(text: str) -> List[CaseFoldData]:
    """Parse CaseFolding.txt."""
    folds: List[CaseFoldData] = []
    for line in text.splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split(";")
        if len(parts) < 4:
            continue
        cp = int(parts[0].strip(), 16)
        status = parts[1].strip()
        mapping_str = parts[2].strip()
        mapping = [int(c, 16) for c in mapping_str.split()]
        folds.append(CaseFoldData(cp=cp, status=status, mapping=mapping))
    return folds


def parse_simple_case_maps(records: Dict[int, CodepointData], unidata_text: str) -> Dict[int, CodepointData]:
    """Parse UnicodeData.txt for simple case mappings (fields 12-14)."""
    for line in unidata_text.splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        fields = line.split(";")
        if len(fields) < 15:
            continue
        cp = int(fields[0], 16)
        if cp not in records:
            continue
        if fields[12]:
            records[cp].simple_upper = int(fields[12], 16)
        if fields[13]:
            records[cp].simple_lower = int(fields[13], 16)
        if fields[14]:
            records[cp].simple_title = int(fields[14], 16)
    return records


def parse_decomposition(records: Dict[int, CodepointData]) -> Dict[int, List[int]]:
    """Extract decomposition mappings from UnicodeData.txt field 5."""
    result: Dict[int, List[int]] = {}
    for cp, rec in records.items():
        decomposition = rec.decomposition.strip()
        if not decomposition:
            continue
        parts = decomposition.split()
        if parts and parts[0].startswith("<"):
            parts = parts[1:]
        if not parts:
            continue
        result[cp] = [int(item, 16) for item in parts]
    return result


def count_data_lines(text: str) -> int:
    count = 0
    for raw_line in text.splitlines():
        line = raw_line.split("#", 1)[0].strip()
        if line:
            count += 1
    return count


# ─── Table generation ──────────────────────────────────────────────

def build_property_bitmask(properties: Dict[str, List[Tuple[int, int, bool]]], max_cp: int = 0x10FFFF) -> List[List[int]]:
    """Build per-codepoint bitmask for binary properties.

    Returns list of bitmasks indexed by codepoint (for BMP only, SMP is special).
    Actually better to store as property ranges and generate a lookup table.
    """
    # Stage 2 table for BMP: 256 high bytes × 256 low bytes = 65536 entries
    table = [[0] * 256 for _ in range(256)]
    # Map property name → bit index
    prop_bits = {p: 1 << i for i, p in enumerate(BINARY_PROPS)}
    # Already computed above in build_property_ranges. We'll use ranges instead.
    return table

def merge_ranges(ranges: List[Tuple[int, int]]) -> List[Tuple[int, int]]:
    if not ranges:
        return []

    merged: List[Tuple[int, int]] = []
    for lo, hi in sorted(ranges):
        if not merged or lo > merged[-1][1] + 1:
            merged.append((lo, hi))
        else:
            merged[-1] = (merged[-1][0], max(merged[-1][1], hi))
    return merged


def build_property_ranges(*texts: str) -> Dict[str, List[Tuple[int, int]]]:
    """Build merged range lists per binary property from one or more UCD files."""
    result: Dict[str, List[Tuple[int, int]]] = {}

    for text in texts:
        for raw_line in text.splitlines():
            line = raw_line.split("#", 1)[0].strip()
            if not line:
                continue
            parts = [part.strip() for part in line.split(";")]
            if len(parts) < 2:
                continue
            range_str = parts[0]
            prop = parts[1]
            if prop not in BINARY_PROPS:
                continue
            if prop not in result:
                result[prop] = []
            if ".." in range_str:
                lo, hi = range_str.split("..")
                result[prop].append((int(lo, 16), int(hi, 16)))
            else:
                cp = int(range_str, 16)
                result[prop].append((cp, cp))

    for prop, ranges in list(result.items()):
        result[prop] = merge_ranges(ranges)

    return result


def build_category_table(records: Dict[int, CodepointData]) -> List[List[int]]:
    """Build BMP (0-0xFFFF) category lookup as stage-2 table.
    category_bits[high][low] = int external catalog number.
    """
    table = [[CAT_ENUM_VALUES["Cn"]] * 256 for _ in range(256)]
    for cp, rec in records.items():
        if cp > 0xFFFF:
            continue
        hi = (cp >> 8) & 0xFF
        lo = cp & 0xFF
        if rec.category in CAT_ENUM_VALUES:
            table[hi][lo] = CAT_ENUM_VALUES[rec.category]
    return table


def build_smp_category_ranges(records: Dict[int, CodepointData]) -> List[Tuple[int, int, int]]:
    """Build SMP (0x10000-0x10FFFF) range list as (lo, hi, category_id)."""
    ranges: List[Tuple[int, int, int]] = []
    range_start = 0x10000
    current_cat = records.get(range_start).category if range_start in records else "Cn"

    for cp in range(0x10001, 0x10FFFF + 1):
        rec = records.get(cp)
        cat = rec.category if rec else "Cn"
        if cat != current_cat:
            ranges.append((range_start, cp - 1, CAT_ENUM_VALUES[current_cat]))
            range_start = cp
            current_cat = cat

    ranges.append((range_start, 0x10FFFF, CAT_ENUM_VALUES[current_cat]))
    return ranges


def build_simple_case_map(records: Dict[int, CodepointData], field: str = "lower") -> List[Tuple[int, int, int, int]]:
    """Build delta-based case mapping for BMP as (hi, lo, delta, flag).

    field: "lower" → simple_lower, "upper" → simple_upper, "title" → simple_title
    Most codepoints map to themselves (delta=0). We store only exceptions.
    """
    attr = {"lower": "simple_lower", "upper": "simple_upper", "title": "simple_title"}[field]
    ranges: List[Tuple[int, int, int]] = []  # (lo, hi, delta)
    for cp in range(0, 0xFFFF + 1):
        rec = records.get(cp)
        if rec is None:
            continue
        target = getattr(rec, attr, -1)
        if target == -1:
            continue
        if target == cp:
            continue
        delta = target - cp
        ranges.append((cp, cp, delta))
    # Merge adjacent
    merged: List[Tuple[int, int, int]] = []
    for r in ranges:
        if merged and merged[-1][2] == r[2] and merged[-1][1] + 1 == r[0]:
            merged[-1] = (merged[-1][0], r[1], r[2])
        else:
            merged.append(r)
    # For SMP, use range list too
    smp_ranges: List[Tuple[int, int, int]] = []
    for cp in range(0x10000, 0x10FFFF + 1):
        rec = records.get(cp)
        if rec is None:
            continue
        target = getattr(rec, attr, -1)
        if target == -1:
            continue
        if target == cp:
            continue
        delta = target - cp
        smp_ranges.append((cp, cp, delta))
    merged_smp: List[Tuple[int, int, int]] = []
    for r in smp_ranges:
        if merged_smp and merged_smp[-1][2] == r[2] and merged_smp[-1][1] + 1 == r[0]:
            merged_smp[-1] = (merged_smp[-1][0], r[1], r[2])
        else:
            merged_smp.append(r)
    return merged, merged_smp


def build_case_fold_table(folds: List[CaseFoldData]) -> Tuple[List[Tuple[int, int, int]], Dict[int, List[int]]]:
    """Build simple (C/S) and full (F) case fold tables.

    Returns (simple_ranges, full_map).
    simple_ranges: [(lo, hi, delta)] for BMP status=C or S
    full_map: {cp: [codepoint...]} for status=F or C when output length > 1
    """
    simple_ranges: List[Tuple[int, int, int]] = []
    full_map: Dict[int, List[int]] = {}

    for f in folds:
        if f.status in ("C", "S") and len(f.mapping) == 1:
            if f.cp != f.mapping[0]:
                delta = f.mapping[0] - f.cp
                simple_ranges.append((f.cp, f.cp, delta))
        elif f.status in ("C", "F"):
            # Full fold - may be multi-codepoint
            if len(f.mapping) == 1:
                delta = f.mapping[0] - f.cp
                if delta != 0:
                    simple_ranges.append((f.cp, f.cp, delta))
            else:
                full_map[f.cp] = f.mapping

    # Merge simple ranges
    merged: List[Tuple[int, int, int]] = []
    for r in sorted(simple_ranges):
        if merged and merged[-1][2] == r[2] and merged[-1][1] + 1 == r[0]:
            merged[-1] = (merged[-1][0], r[1], r[2])
        else:
            merged.append(r)

    return merged, full_map


def is_hangul_syllable(cp: int) -> bool:
    return HANGUL_SBASE <= cp < (HANGUL_SBASE + HANGUL_SCOUNT)


def is_hangul_lv(cp: int) -> bool:
    if not is_hangul_syllable(cp):
        return False
    return ((cp - HANGUL_SBASE) % HANGUL_TCOUNT) == 0


def is_hangul_l(cp: int) -> bool:
    return HANGUL_LBASE <= cp < (HANGUL_LBASE + HANGUL_LCOUNT)


def is_hangul_v(cp: int) -> bool:
    return HANGUL_VBASE <= cp < (HANGUL_VBASE + HANGUL_VCOUNT)


def is_hangul_t(cp: int) -> bool:
    return (HANGUL_TBASE + 1) <= cp < (HANGUL_TBASE + HANGUL_TCOUNT)


def hangul_decomposition(cp: int) -> Optional[List[int]]:
    if not is_hangul_syllable(cp):
        return None
    sindex = cp - HANGUL_SBASE
    lpart = HANGUL_LBASE + (sindex // HANGUL_NCOUNT)
    vpart = HANGUL_VBASE + ((sindex % HANGUL_NCOUNT) // HANGUL_TCOUNT)
    tpart = HANGUL_TBASE + (sindex % HANGUL_TCOUNT)
    if tpart == HANGUL_TBASE:
        return [lpart, vpart]
    return [lpart, vpart, tpart]


def expand_decomposition(
    cp: int,
    decomp_kind: Dict[int, int],
    raw_decomp: Dict[int, List[int]],
    compatibility: bool,
    cache: Dict[Tuple[int, bool], List[int]],
) -> List[int]:
    key = (cp, compatibility)
    if key in cache:
        return cache[key]

    if is_hangul_syllable(cp):
        mapping = hangul_decomposition(cp)
        assert mapping is not None
        result: List[int] = []
        for item in mapping:
            result.extend(expand_decomposition(item, decomp_kind, raw_decomp, compatibility, cache))
        cache[key] = result
        return result

    kind = decomp_kind.get(cp, 0)
    if kind == 0:
        cache[key] = [cp]
        return cache[key]
    if (kind == 2) and (not compatibility):
        cache[key] = [cp]
        return cache[key]

    mapping = raw_decomp.get(cp, [])
    if not mapping:
        cache[key] = [cp]
        return cache[key]

    result = []
    for item in mapping:
        result.extend(expand_decomposition(item, decomp_kind, raw_decomp, compatibility, cache))
    cache[key] = result
    return result


def build_decomposition_tables(
    records: Dict[int, CodepointData],
    raw_decomp: Dict[int, List[int]],
) -> Tuple[List[Tuple[int, int, int]], List[Tuple[int, int, int]], Dict[int, List[int]]]:
    decomp_kind: Dict[int, int] = {}
    for cp, rec in records.items():
        decomposition = rec.decomposition.strip()
        if not decomposition:
            continue
        decomp_kind[cp] = 2 if decomposition.startswith("<") else 1

    canon_cache: Dict[Tuple[int, bool], List[int]] = {}
    compat_cache: Dict[Tuple[int, bool], List[int]] = {}
    canonical_map: Dict[int, List[int]] = {}
    effective_map: Dict[int, List[int]] = {}

    for cp in range(0x110000):
        canonical = expand_decomposition(cp, decomp_kind, raw_decomp, False, canon_cache)
        compatibility = expand_decomposition(cp, decomp_kind, raw_decomp, True, compat_cache)
        if canonical != [cp]:
            canonical_map[cp] = canonical
            effective_map[cp] = canonical
        if decomp_kind.get(cp, 0) == 2 and compatibility != [cp]:
            effective_map[cp] = compatibility

    def build_ranges(lo_cp: int, hi_cp: int) -> List[Tuple[int, int, int]]:
        ranges: List[Tuple[int, int, int]] = []
        current_lo = lo_cp
        current_kind = 0

        def cp_kind(value: int) -> int:
            if decomp_kind.get(value, 0) == 2:
                return 2
            if value in canonical_map:
                return 1
            return 0

        current_kind = cp_kind(lo_cp)
        for cp in range(lo_cp + 1, hi_cp + 1):
            kind = cp_kind(cp)
            if kind != current_kind:
                ranges.append((current_lo, cp - 1, current_kind))
                current_lo = cp
                current_kind = kind
        ranges.append((current_lo, hi_cp, current_kind))
        return ranges

    bmp_ranges = build_ranges(0, 0xFFFF)
    smp_ranges = build_ranges(0x10000, 0x10FFFF)
    return bmp_ranges, smp_ranges, effective_map


def build_ccc_tables(records: Dict[int, CodepointData]) -> Tuple[List[List[int]], List[Tuple[int, int, int]]]:
    bmp_table = [[0] * 256 for _ in range(256)]
    smp_ranges: List[Tuple[int, int, int]] = []

    for cp in range(0x10000):
        rec = records.get(cp)
        if rec is None:
            continue
        bmp_table[(cp >> 8) & 0xFF][cp & 0xFF] = rec.combining

    range_start = 0x10000
    current_ccc = records.get(range_start).combining if range_start in records else 0
    for cp in range(0x10001, 0x10FFFF + 1):
        ccc = records.get(cp).combining if cp in records else 0
        if ccc != current_ccc:
            smp_ranges.append((range_start, cp - 1, current_ccc))
            range_start = cp
            current_ccc = ccc
    smp_ranges.append((range_start, 0x10FFFF, current_ccc))
    return bmp_table, smp_ranges


def build_normalization_property_sets(derived_norm_text: str) -> Set[int]:
    composition_exclusions: Set[int] = set()

    for lo, hi, value in parse_ranges(derived_norm_text):
        prop = value
        if prop == "Full_Composition_Exclusion":
            for cp in range(lo, hi + 1):
                composition_exclusions.add(cp)
    return composition_exclusions


def build_composition_table(
    records: Dict[int, CodepointData],
    raw_decomp: Dict[int, List[int]],
    composition_exclusions: Set[int],
) -> List[Tuple[int, int, int]]:
    entries: List[Tuple[int, int, int]] = []
    seen: Set[Tuple[int, int]] = set()

    for cp, rec in records.items():
        if cp in composition_exclusions:
            continue
        if rec.decomposition.startswith("<"):
            continue
        mapping = raw_decomp.get(cp)
        if mapping is None:
            continue
        if len(mapping) != 2:
            continue
        first_rec = records.get(mapping[0])
        if (first_rec is not None) and (first_rec.combining != 0):
            continue
        pair = (mapping[0], mapping[1])
        if pair in seen:
            continue
        seen.add(pair)
        entries.append((pair[0], pair[1], cp))

    entries.sort()
    return entries


# ─── Pascal code generation ────────────────────────────────────────

def pascal_stage2_table(table: List[List[int]], name: str, elem_type: str = "Byte") -> str:
    """Generate a Pascal const stage-2 table for BMP."""
    lines = [f"  {name}: array[0..255, 0..255] of {elem_type} = ("]
    for hi in range(256):
        row = ", ".join(str(v) for v in table[hi])
        sep = "," if hi < 255 else ""
        lines.append(f"    // hi=${hi:02X}")
        lines.append(f"    ({row}){sep}")
    lines.append("  );")
    return "\n".join(lines)


def pascal_ranges_list(ranges: List[Tuple[int, int, int]], name: str, elem_type: str = "Byte") -> str:
    """Generate a Pascal const array of TCodepointRange3 records (Lo, Hi, Value)."""
    if not ranges:
        return f"  {name}: array[0..0] of TCodepointRange3 = ( (0, 0, 0) );"
    lines = [f"  {name}: array[0..{len(ranges)-1}] of TCodepointRange3 = ("]
    for i, (lo, hi, val) in enumerate(ranges):
        sep = "," if i < len(ranges) - 1 else ""
        if lo == hi:
            lines.append(f"    (Lo: ${lo:06X}; Hi: ${hi:06X}; Value: {val}){sep}")
        else:
            lines.append(f"    (Lo: ${lo:06X}; Hi: ${hi:06X}; Value: {val}){sep}")
    lines.append("  );")
    return "\n".join(lines)


def pascal_range_pair_list(ranges: List[Tuple[int, int, int]], name: str) -> str:
    """Generate a Pascal const array of TCodepointRange2 (Lo, Hi, Delta)."""
    if not ranges:
        return f"  {name}: array[0..0] of TCodepointRange2 = ( (0, 0, 0) );"
    lines = [f"  {name}: array[0..{len(ranges)-1}] of TCodepointRange2 = ("]
    for i, (lo, hi, delta) in enumerate(ranges):
        sep = "," if i < len(ranges) - 1 else ""
        lines.append(f"    (Lo: ${lo:06X}; Hi: ${hi:06X}; Delta: {delta}){sep}")
    lines.append("  );")
    return "\n".join(lines)


def pascal_binary_prop_ranges(props: Dict[str, List[Tuple[int, int]]]) -> str:
    """Generate binary property range tables."""
    lines = []
    for prop in BINARY_PROPS:
        ranges = props.get(prop, [])
        if not ranges:
            lines.append(f"  // {prop}: (empty)")
            continue
        name = f"PROP_{prop.upper()}_RANGES"
        lines.append(f"  // {prop} ({len(ranges)} ranges)")
        lines.append(f"  {name}: array[0..{len(ranges)-1}] of TCodepointRange2 = (")
        for i, (lo, hi) in enumerate(ranges):
            sep = "," if i < len(ranges) - 1 else ""
            lines.append(f"    (Lo: ${lo:06X}; Hi: ${hi:06X}; Delta: 0){sep}")
        lines.append("  );")
        lines.append(f"  {name}_COUNT = {len(ranges)};")
    return "\n".join(lines)


def pascal_full_case_fold(full_map: Dict[int, List[int]], name: str = "FULL_CASE_FOLD") -> str:
    """Generate Pascal case fold table for multi-codepoint folds."""
    if not full_map:
        return f"  {name}: array[0..0] of TCaseFoldEntry = ( (Cp: 0; Len: 0; Map: (0, 0, 0, 0, 0, 0, 0, 0)) );"
    entries = sorted(full_map.items())
    lines = [f"  {name}: array[0..{len(entries)-1}] of TCaseFoldEntry = ("]
    for idx, (cp, mapping) in enumerate(entries):
        sep = "," if idx < len(entries) - 1 else ""
        # Pad mapping to 8 entries (max fold length)
        padded = mapping + [0] * (8 - len(mapping))
        map_str = ", ".join(f"${c:04X}" for c in padded)
        lines.append(f"    (Cp: ${cp:04X}; Len: {len(mapping)}; Map: ({map_str})){sep}")
    lines.append("  );")
    return "\n".join(lines)


def pascal_decomp_map(entries: Dict[int, List[int]], name: str) -> str:
    if not entries:
        zero_map = ", ".join("0" for _ in range(MAX_DECOMP_MAP_LEN))
        return (
            f"  {name}: array[0..0] of TDecompEntry = ("
            f" (Cp: 0; Len: 0; Map: ({zero_map})) );"
        )

    items = sorted(entries.items())
    lines = [f"  {name}: array[0..{len(items)-1}] of TDecompEntry = ("]
    for idx, (cp, mapping) in enumerate(items):
        if len(mapping) > MAX_DECOMP_MAP_LEN:
            raise ValueError(f"Decomposition for U+{cp:04X} exceeds MAX_DECOMP_MAP_LEN={MAX_DECOMP_MAP_LEN}")
        padded = mapping + [0] * (MAX_DECOMP_MAP_LEN - len(mapping))
        map_str = ", ".join(f"${value:04X}" for value in padded)
        sep = "," if idx < len(items) - 1 else ""
        lines.append(f"    (Cp: ${cp:06X}; Len: {len(mapping)}; Map: ({map_str})){sep}")
    lines.append("  );")
    return "\n".join(lines)


def pascal_compose_map(entries: List[Tuple[int, int, int]], name: str) -> str:
    if not entries:
        return (
            f"  {name}: array[0..0] of TComposeEntry = ("
            f" (Starter: 0; Combining: 0; ResultCp: 0) );"
        )

    lines = [f"  {name}: array[0..{len(entries)-1}] of TComposeEntry = ("]
    for idx, (starter, combining, result_cp) in enumerate(entries):
        sep = "," if idx < len(entries) - 1 else ""
        lines.append(
            f"    (Starter: ${starter:06X}; Combining: ${combining:06X}; ResultCp: ${result_cp:06X}){sep}"
        )
    lines.append("  );")
    return "\n".join(lines)


# ─── Main ──────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Generate Unicode UCD → Pascal .inc tables")
    parser.add_argument("--version", default=DEFAULT_VERSION, help="Unicode version (e.g. 16.0.0)")
    parser.add_argument("--output-dir", default=".", help="Output directory for .inc files")
    args = parser.parse_args()

    print(f"Generating Unicode {args.version} data tables for nextpas.core.text.unicode", file=sys.stderr)

    os.makedirs(args.output_dir, exist_ok=True)

    # ── Step 1: Download all UCD files ──
    print("Step 1/5: Downloading UCD files...", file=sys.stderr)
    unidata_text = download_ucd(args.version, "UnicodeData.txt")
    derived_text = download_ucd(args.version, "DerivedCoreProperties.txt")
    casefold_text = download_ucd(args.version, "CaseFolding.txt")
    emoji_text = download_ucd(args.version, "emoji/emoji-data.txt")
    derived_norm_text = download_ucd(args.version, "DerivedNormalizationProps.txt")
    normalization_test_text = download_ucd(args.version, "NormalizationTest.txt")

    # Optional but useful
    try:
        proplist_text = download_ucd(args.version, "PropList.txt")
    except urllib.error.HTTPError:
        proplist_text = ""
    try:
        normalization_corrections_text = download_ucd(args.version, "NormalizationCorrections.txt")
    except urllib.error.HTTPError:
        normalization_corrections_text = ""

    # ── Step 2: Parse ──
    print("Step 2/5: Parsing UCD data...", file=sys.stderr)
    records = parse_unicode_data(unidata_text)
    records = parse_simple_case_maps(records, unidata_text)
    folds = parse_case_folding(casefold_text)
    raw_decomposition = parse_decomposition(records)
    properties = build_property_ranges(derived_text, proplist_text, emoji_text)

    # ── Step 3: Build tables ──
    print("Step 3/5: Building lookup tables...", file=sys.stderr)
    cat_table = build_category_table(records)
    smp_ranges = build_smp_category_ranges(records)

    simple_lower, smp_lower = build_simple_case_map(records, "lower")
    simple_upper, smp_upper = build_simple_case_map(records, "upper")
    simple_title, smp_title = build_simple_case_map(records, "title")

    fold_simple, fold_full = build_case_fold_table(folds)
    decomp_bmp_ranges, decomp_smp_ranges, decomp_effective_map = build_decomposition_tables(records, raw_decomposition)
    ccc_bmp_table, ccc_smp_ranges = build_ccc_tables(records)
    composition_exclusions = build_normalization_property_sets(derived_norm_text)
    compose_entries = build_composition_table(records, raw_decomposition, composition_exclusions)

    # ── Step 4: Generate main data .inc ──
    print("Step 4/5: Writing Pascal .inc files...", file=sys.stderr)

    cat_output = f"""// {{Auto-generated by gen_unicode_data.py — Unicode {args.version}}}
// Generated: see core/scripts/gen_unicode_data.py
// Do not edit manually.

const
  // ── BMP Category Lookup (stage-2: [high][low] → TGeneralCategory ordinal) ──
{pascal_stage2_table(cat_table, "BMP_CATEGORY_TABLE", "Byte")}

  // ── SMP Category Ranges (0x10000-0x10FFFF) ──
  SMP_CATEGORY_RANGES_COUNT = {len(smp_ranges)};
{pascal_ranges_list(smp_ranges, "SMP_CATEGORY_RANGES")}

  // ── Simple uppercase mapping (BMP) ──
  // Delta = simple_upper - codepoint
  BMP_UPPER_DELTA_COUNT = {len(simple_upper)};
{pascal_range_pair_list(simple_upper, "BMP_UPPER_DELTA")}

  // ── Simple uppercase mapping (SMP) ──
  SMP_UPPER_DELTA_COUNT = {len(smp_upper)};
{pascal_range_pair_list(smp_upper, "SMP_UPPER_DELTA")}

  // ── Simple lowercase mapping (BMP) ──
  BMP_LOWER_DELTA_COUNT = {len(simple_lower)};
{pascal_range_pair_list(simple_lower, "BMP_LOWER_DELTA")}

  // ── Simple lowercase mapping (SMP) ──
  SMP_LOWER_DELTA_COUNT = {len(smp_lower)};
{pascal_range_pair_list(smp_lower, "SMP_LOWER_DELTA")}

  // ── Simple titlecase mapping (BMP) ──
  BMP_TITLE_DELTA_COUNT = {len(simple_title)};
{pascal_range_pair_list(simple_title, "BMP_TITLE_DELTA")}

  // ── Simple titlecase mapping (SMP) ──
  SMP_TITLE_DELTA_COUNT = {len(smp_title)};
{pascal_range_pair_list(smp_title, "SMP_TITLE_DELTA")}
"""

    # ── Step 5: Generate binary properties .inc ──
    prop_output = f"""// {{Auto-generated by gen_unicode_data.py — Unicode {args.version}}}
// Binary property range tables.

const
  BINARY_PROP_COUNT = {len(BINARY_PROPS)};

{pascal_binary_prop_ranges(properties)}
"""

    # ── Step 6: Generate case fold .inc ──
    fold_output = f"""// {{Auto-generated by gen_unicode_data.py — Unicode {args.version}}}
// Case folding data from CaseFolding.txt.

const
  // ── Simple case fold (C/S) ranges: Delta ──
  CASE_FOLD_SIMPLE_COUNT = {len(fold_simple)};
{pascal_range_pair_list(fold_simple, "CASE_FOLD_SIMPLE_DELTA")}

  // ── Full case fold (F/C) — multi-codepoint mappings ──
{pascal_full_case_fold(fold_full, "CASE_FOLD_FULL")}
  CASE_FOLD_FULL_COUNT = {len(fold_full)};
"""

    decomp_bmp_map = {cp: mapping for cp, mapping in decomp_effective_map.items() if cp <= 0xFFFF}
    decomp_smp_map = {cp: mapping for cp, mapping in decomp_effective_map.items() if cp > 0xFFFF}

    normalize_output = f"""// {{Auto-generated by gen_unicode_data.py — Unicode {args.version}}}
// Unicode normalization data from UnicodeData.txt and DerivedNormalizationProps.txt.

type
  TDecompMap = array[0..{MAX_DECOMP_MAP_LEN - 1}] of TUnicodeCodepoint;

  TDecompEntry = record
    Cp: TUnicodeCodepoint;
    Len: Byte;
    Map: TDecompMap;
  end;

  TComposeEntry = record
    Starter: TUnicodeCodepoint;
    Combining: TUnicodeCodepoint;
    ResultCp: TUnicodeCodepoint;
  end;

const
  DECOMP_BMP_RANGES_COUNT = {len(decomp_bmp_ranges)};
{pascal_ranges_list(decomp_bmp_ranges, "DECOMP_BMP_RANGES")}

  DECOMP_BMP_MAP_COUNT = {len(decomp_bmp_map)};
{pascal_decomp_map(decomp_bmp_map, "DECOMP_BMP_MAP")}

  DECOMP_SMP_RANGES_COUNT = {len(decomp_smp_ranges)};
{pascal_ranges_list(decomp_smp_ranges, "DECOMP_SMP_RANGES")}

  DECOMP_SMP_MAP_COUNT = {len(decomp_smp_map)};
{pascal_decomp_map(decomp_smp_map, "DECOMP_SMP_MAP")}

{pascal_stage2_table(ccc_bmp_table, "CCC_TABLE", "Byte")}

  CCC_SMP_RANGES_COUNT = {len(ccc_smp_ranges)};
{pascal_ranges_list(ccc_smp_ranges, "CCC_SMP_RANGES")}

  COMPOSE_TABLE_COUNT = {len(compose_entries)};
{pascal_compose_map(compose_entries, "COMPOSE_TABLE")}
"""

    # ── Write files ──
    files = {
        "nextpas.core.text.unicode.data.inc": cat_output,
        "nextpas.core.text.unicode.props.inc": prop_output,
        "nextpas.core.text.unicode.casefold.inc": fold_output,
        "nextpas.core.text.unicode.normalize.inc": normalize_output,
    }

    for fname, fcontent in files.items():
        fpath = os.path.join(args.output_dir, fname)
        with open(fpath, "w") as f:
            f.write(fcontent)
        print(f"  Wrote {fpath} ({len(fcontent)} bytes)", file=sys.stderr)

    # ── Statistics ──
    print(file=sys.stderr)
    print(f"Unicode {args.version} table generation complete.", file=sys.stderr)
    print(f"  Total codepoints: {len(records)}", file=sys.stderr)
    unique_cats = set(r.category for r in records.values())
    print(f"  Categories: {len(unique_cats)} ({', '.join(sorted(unique_cats))})", file=sys.stderr)
    print(f"  BMP category table: 256×256 = 65536 entries", file=sys.stderr)
    print(f"  SMP category ranges: {len(smp_ranges)}", file=sys.stderr)
    print(f"  Upper case deltas (BMP): {len(simple_upper)}", file=sys.stderr)
    print(f"  Lower case deltas (BMP): {len(simple_lower)}", file=sys.stderr)
    print(f"  Case fold simple deltas: {len(fold_simple)}", file=sys.stderr)
    print(f"  Case fold full entries: {len(fold_full)}", file=sys.stderr)
    print(f"  Decomposition ranges (BMP): {len(decomp_bmp_ranges)}", file=sys.stderr)
    print(f"  Decomposition map entries (BMP): {len(decomp_bmp_map)}", file=sys.stderr)
    print(f"  Decomposition ranges (SMP): {len(decomp_smp_ranges)}", file=sys.stderr)
    print(f"  Decomposition map entries (SMP): {len(decomp_smp_map)}", file=sys.stderr)
    print(f"  Composition exclusions: {len(composition_exclusions)}", file=sys.stderr)
    print(f"  Composition entries: {len(compose_entries)}", file=sys.stderr)
    print(f"  CCC SMP ranges: {len(ccc_smp_ranges)}", file=sys.stderr)
    print(f"  NormalizationTest data rows: {count_data_lines(normalization_test_text)}", file=sys.stderr)
    print(f"  NormalizationCorrections rows: {count_data_lines(normalization_corrections_text)}", file=sys.stderr)
    for prop in BINARY_PROPS:
        count = len(properties.get(prop, []))
        if count > 0:
            print(f"  Property '{prop}': {count} ranges", file=sys.stderr)


if __name__ == "__main__":
    main()

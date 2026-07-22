#!/usr/bin/env python3
"""Generate nextpas.core.text.unicode.script_extensions.inc from UCD ScriptExtensions.txt."""
import argparse
import re
import urllib.request
from pathlib import Path

UCD = "https://www.unicode.org/Public/{v}/ucd/"

def load_script_names(repo: Path) -> dict:
    src = (repo / "core/scripts/gen_unicode_script_block.py").read_text()
    ns = {}
    exec(src.split("def parse_scripts")[0], ns)
    return ns["SCRIPT_NAMES"]

def load_short_to_long(version: str) -> dict:
    text = urllib.request.urlopen(UCD.format(v=version) + "PropertyValueAliases.txt", timeout=60).read().decode()
    m = {}
    for line in text.splitlines():
        if not line.startswith("sc ;"):
            continue
        parts = [p.strip() for p in line.split(";")]
        if len(parts) >= 3:
            m[parts[1]] = parts[2]
    return m

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", default="16.0.0")
    ap.add_argument("--output-dir", default="core/src")
    ap.add_argument("--repo-root", default=".")
    args = ap.parse_args()
    root = Path(args.repo_root)
    SCRIPT_NAMES = load_script_names(root)
    short_to_long = load_short_to_long(args.version)
    text = urllib.request.urlopen(UCD.format(v=args.version) + "ScriptExtensions.txt", timeout=60).read().decode()
    entries = []
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or ";" not in line:
            continue
        left, right = line.split(";", 1)
        cp_range = left.strip()
        shorts = right.split("#")[0].strip().split()
        pascals = []
        for s in shorts:
            long = short_to_long.get(s)
            pas = SCRIPT_NAMES.get(long or "", None)
            pascals.append(pas or "usUnknown")
        if ".." in cp_range:
            a, b = cp_range.split("..")
            lo, hi = int(a, 16), int(b, 16)
        else:
            lo = hi = int(cp_range, 16)
        entries.append((lo, hi, pascals))
    entries.sort(key=lambda x: x[0])
    flat, key_to_off, rows = [], {}, []
    for lo, hi, scripts in entries:
        key = tuple(scripts)
        if key not in key_to_off:
            key_to_off[key] = len(flat)
            flat.extend(scripts)
        rows.append((lo, hi, key_to_off[key], len(scripts)))
    out = [
        f"// {{Auto-generated — Unicode {args.version} ScriptExtensions.txt}}",
        "// Do not edit manually.",
        "",
        "const",
        f"  SCX_POOL_COUNT = {len(flat)};",
        f"  SCX_RANGES_COUNT = {len(rows)};",
        "",
        "  SCX_POOL: array[0..SCX_POOL_COUNT - 1] of Word = (",
    ]
    for i, name in enumerate(flat):
        out.append(f"    Ord({name})" + ("," if i < len(flat) - 1 else ""))
    out += [
        "  );",
        "",
        "  SCX_RANGES: array[0..SCX_RANGES_COUNT - 1] of record",
        "    Lo: TUnicodeCodepoint;",
        "    Hi: TUnicodeCodepoint;",
        "    Off: Word;",
        "    Len: Byte;",
        "  end = (",
    ]
    for i, (lo, hi, off, ln) in enumerate(rows):
        out.append(f"    (Lo: ${lo:04X}; Hi: ${hi:04X}; Off: {off}; Len: {ln})" + ("," if i < len(rows) - 1 else ""))
    out.append("  );")
    path = Path(args.output_dir) / "nextpas.core.text.unicode.script_extensions.inc"
    path.write_text("\n".join(out) + "\n")
    print(f"Wrote {path} pool={len(flat)} ranges={len(rows)}")

if __name__ == "__main__":
    main()

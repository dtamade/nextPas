#!/usr/bin/env python3
"""
vzeroupper audit: find AVX2/AVX512 functions that use ymm/zmm registers
but lack a vzeroupper before returning.

Scans .pas and .inc files in src/ matching nextpas.core.simd.avx2* and avx512*.
Reports functions where ymm/zmm is used but no vzeroupper appears in the same
asm block.
"""

import re
import sys
from pathlib import Path

SRC = Path(__file__).resolve().parent.parent / "src"

PATTERNS = list(SRC.glob("nextpas.core.simd.avx2*")) + list(SRC.glob("nextpas.core.simd.avx512*"))

YMM_RE = re.compile(r'\b[yz]mm\d+\b', re.IGNORECASE)
VZEROUPPER_RE = re.compile(r'\bvzeroupper\b', re.IGNORECASE)
FUNC_RE = re.compile(r'^(function|procedure)\s+(\w+)', re.IGNORECASE)

def audit_file(path):
    findings = []
    lines = path.read_text(errors='replace').splitlines()

    current_func = None
    func_start = 0
    in_asm = False
    has_ymm = False
    has_vzeroupper = False
    asm_depth = 0

    for i, line in enumerate(lines, 1):
        stripped = line.strip().lower()

        # Track function boundaries
        m = FUNC_RE.match(line.strip())
        if m:
            # Check previous function
            if current_func and has_ymm and not has_vzeroupper:
                findings.append((func_start, current_func))
            current_func = m.group(2)
            func_start = i
            has_ymm = False
            has_vzeroupper = False

        # Track asm blocks
        if stripped.startswith('asm') and not stripped.startswith('asm_'):
            in_asm = True
            asm_depth += 1
        if in_asm and ('end;' in stripped or 'end (' in stripped):
            asm_depth -= 1
            if asm_depth <= 0:
                in_asm = False
                asm_depth = 0

        # Check for ymm/zmm usage
        if YMM_RE.search(line):
            has_ymm = True

        # Check for vzeroupper
        if VZEROUPPER_RE.search(line):
            has_vzeroupper = True

    # Check last function
    if current_func and has_ymm and not has_vzeroupper:
        findings.append((func_start, current_func))

    return findings

def main():
    total = 0
    for path in sorted(PATTERNS):
        if not path.is_file():
            continue
        findings = audit_file(path)
        if findings:
            rel = path.relative_to(SRC.parent)
            for line_no, func_name in findings:
                print(f"  {rel}:{line_no}: {func_name}")
                total += 1

    if total == 0:
        print("OK: all ymm/zmm functions have vzeroupper")
    else:
        print(f"\n{total} function(s) missing vzeroupper")
    return 1 if total > 0 else 0

if __name__ == "__main__":
    sys.exit(main())

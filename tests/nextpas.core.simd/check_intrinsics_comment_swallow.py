#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
TARGETS = [
    Path('src/nextpas.core.simd.intrinsics.aes.pas'),
    Path('src/nextpas.core.simd.intrinsics.avx.pas'),
    Path('src/nextpas.core.simd.intrinsics.avx2.pas'),
    Path('src/nextpas.core.simd.intrinsics.avx512.pas'),
    Path('src/nextpas.core.simd.intrinsics.fma3.pas'),
    Path('src/nextpas.core.simd.intrinsics.pas'),
    Path('src/nextpas.core.simd.intrinsics.sha.pas'),
    Path('src/nextpas.core.simd.intrinsics.sse.pas'),
    Path('src/nextpas.core.simd.intrinsics.sse3.pas'),
    Path('src/nextpas.core.simd.intrinsics.sse41.pas'),
    Path('src/nextpas.core.simd.intrinsics.sse42.pas'),
    Path('src/nextpas.core.simd.intrinsics.sve2.pas'),
    Path('src/nextpas.core.simd.intrinsics.mmx.pas'),
    Path('src/nextpas.core.simd.intrinsics.x86.sse2.pas'),
]
GENERIC_PATTERNS = [
    re.compile(r'//\s+.*function\s+'),
    re.compile(r'//\s+.*procedure\s+'),
    re.compile(r'//\s+.*Result\s*:='),
    re.compile(r'//\s+.*FillChar\(Result'),
    re.compile(r'//\s+.*for\s+.+\s+do'),
    re.compile(r'//\s+.*case\s+.+\s+of'),
    re.compile(r'//.*\belse\b'),
    re.compile(r'//.*\bend[.;]?\b'),
]
X86_BACKEND_TARGETS = {
    Path('src/nextpas.core.simd.intrinsics.x86.sse2.pas'),
    Path('src/nextpas.core.simd.intrinsics.mmx.pas'),
}
ASM_INSTRUCTION_PATTERN = re.compile(
    r'\b(?:'
    r'movdqa|movdqu|movapd|movupd|movaps|movups|movsd|movss|movq|movd|movhpd|movlpd|movntpd|movntps|movntdq|movnti|mov|'
    r'push|pop|'
    r'pxor|xorpd|xorps|'
    r'punpcklbw|punpcklwd|punpckldq|punpcklqdq|punpckhwd|punpckhdq|punpckhqdq|'
    r'unpcklpd|unpckhpd|unpcklps|unpckhps|'
    r'pshufd|pshuflw|pshufhw|shufps|shufpd|'
    r'paddb|paddw|paddd|paddq|paddsb|paddsw|paddusb|paddusw|'
    r'psubb|psubsw|psubsb|psubusb|psubusw|psllw|pslld|psllq|psrlw|psrld|psrlq|psraw|psrad|por|pand|pandn|'
    r'pmuludq|pmullw|pmulhw|pmulhuw|pmaddwd|pavgb|pavgw|psadbw|'
    r'pcmpeqb|pcmpeqw|pcmpeqd|pcmpgtb|pcmpgtw|pcmpgtd|pmaxsw|pminsw|'
    r'minps|maxps|cmp|je|jmp|pinsrw|pextrw|maskmovdqu|psrldq|pslldq|cvtsi2sd|cvttpd2ps|clflush|lfence|mfence|pause'
    r')\b\s+[^/]+'
)
INLINE_DIRECTIVE_TOKENS = ('{$ELSE}', '{$ENDIF}', '{$ELSEIF}')
COMMENT_SWALLOWED_ASM_MARKERS = ('在栈', '参数通过栈', '结果为全', '直接从栈')
COMMENT_SWALLOWED_LABEL_PATTERN = re.compile(r'@[A-Za-z_][A-Za-z0-9_]*:')
ILLEGAL_IMMEDIATE_BRACE_PATTERN = re.compile(
    r'\b(?:cmp|pshufd|pshuflw|pshufhw|shufps)\b[^\n]*\}'
)


def has_inline_directive(line: str) -> bool:
    stripped = line.strip()
    if stripped.startswith(('{$', 'function', 'procedure')):
        return False
    return any(token in line for token in INLINE_DIRECTIVE_TOKENS)


def has_illegal_brace(line: str) -> bool:
    stripped = line.strip()
    if stripped.startswith('//') or '{$' in stripped:
        return False
    return ILLEGAL_IMMEDIATE_BRACE_PATTERN.search(line) is not None


def has_comment_swallowed_asm(line: str) -> bool:
    stripped = line.strip()
    if stripped.startswith('//'):
        return ASM_INSTRUCTION_PATTERN.search(line) is not None and any(marker in line for marker in COMMENT_SWALLOWED_ASM_MARKERS)
    if '//' not in line:
        return False
    code, comment = line.split('//', 1)
    return ASM_INSTRUCTION_PATTERN.search(code) is not None and ASM_INSTRUCTION_PATTERN.search(comment) is not None


def has_comment_swallowed_label(line: str) -> bool:
    stripped = line.strip()
    if stripped.startswith('//') or '//' not in line:
        return False
    code, comment = line.split('//', 1)
    return ASM_INSTRUCTION_PATTERN.search(code) is not None and COMMENT_SWALLOWED_LABEL_PATTERN.search(comment) is not None


def scan_file(path: Path) -> list[str]:
    hits: list[str] = []
    lines = path.read_text(encoding='utf-8', errors='ignore').splitlines()
    is_x86_backend = path.relative_to(REPO_ROOT) in X86_BACKEND_TARGETS
    for lineno, line in enumerate(lines, start=1):
        for pattern in GENERIC_PATTERNS:
            if pattern.search(line):
                hits.append(f'{path.relative_to(REPO_ROOT)}:{lineno}: {line.strip()}')
                break
        else:
            if is_x86_backend and has_inline_directive(line):
                hits.append(f'{path.relative_to(REPO_ROOT)}:{lineno}: inline preprocessor directive shares line with code')
            elif is_x86_backend and has_illegal_brace(line):
                hits.append(f'{path.relative_to(REPO_ROOT)}:{lineno}: illegal immediate brace in asm line')
            elif is_x86_backend and has_comment_swallowed_label(line):
                hits.append(f'{path.relative_to(REPO_ROOT)}:{lineno}: suspicious comment-swallowed asm label')
            elif is_x86_backend and has_comment_swallowed_asm(line):
                hits.append(f'{path.relative_to(REPO_ROOT)}:{lineno}: suspicious comment-swallowed asm sequence')
    return hits


def main() -> int:
    parser = argparse.ArgumentParser(description='Check SIMD intrinsics source hygiene for comment-swallowed code patterns')
    parser.add_argument('--summary-line', action='store_true', help='print single-line summary')
    args = parser.parse_args()

    failures: list[str] = []
    missing: list[str] = []
    for rel in TARGETS:
        full = REPO_ROOT / rel
        if not full.is_file():
            missing.append(str(rel))
            continue
        failures.extend(scan_file(full))

    if missing:
        for item in missing:
            print(f'[INTR-HYGIENE] MISSING {item}')
        return 2

    if failures:
        print('[INTR-HYGIENE] FAIL: suspicious comment-swallowed code patterns found')
        for item in failures:
            print(f'  - {item}')
        if args.summary_line:
            print(f'INTR_HYGIENE_SUMMARY status=FAIL hits={len(failures)}')
        return 1

    print('[INTR-HYGIENE] OK: no suspicious comment-swallowed code patterns in checked intrinsics units')
    if args.summary_line:
        print('INTR_HYGIENE_SUMMARY status=PASS hits=0')
    return 0


if __name__ == '__main__':
    sys.exit(main())

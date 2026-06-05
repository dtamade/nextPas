#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path


LIMITS = {
    "tests/nextpas.core.tls": 287,
    "tests/nextpas.core.simd": 48,
}


def skip_line_comment(a_text: str, a_index: int) -> int:
    while a_index < len(a_text) and a_text[a_index] not in "\r\n":
        a_index += 1
    return a_index


def skip_brace_comment(a_text: str, a_index: int) -> int:
    a_index += 1
    while a_index < len(a_text) and a_text[a_index] != "}":
        a_index += 1
    if a_index < len(a_text):
        a_index += 1
    return a_index


def skip_paren_comment(a_text: str, a_index: int) -> int:
    a_index += 2
    while a_index + 1 < len(a_text) and a_text[a_index : a_index + 2] != "*)":
        a_index += 1
    if a_index + 1 < len(a_text):
        a_index += 2
    return a_index


def first_pascal_token(a_text: str) -> str:
    l_index = 0
    while l_index < len(a_text):
        l_char = a_text[l_index]
        if l_char.isspace():
            l_index += 1
            continue
        if a_text.startswith("//", l_index):
            l_index = skip_line_comment(a_text, l_index)
            continue
        if l_char == "{":
            l_index = skip_brace_comment(a_text, l_index)
            continue
        if a_text.startswith("(*", l_index):
            l_index = skip_paren_comment(a_text, l_index)
            continue
        if l_char.isalpha() or l_char == "_":
            l_start = l_index
            l_index += 1
            while l_index < len(a_text) and (a_text[l_index].isalnum() or a_text[l_index] in "._"):
                l_index += 1
            return a_text[l_start:l_index].lower()
        return ""
    return ""


def count_top_level_programs(a_dir: Path) -> int:
    l_count = 0
    for l_path in sorted(a_dir.iterdir()):
        if not l_path.is_file() or l_path.suffix.lower() not in {".pas", ".lpr"}:
            continue
        l_text = l_path.read_text(encoding="utf-8", errors="ignore")
        if first_pascal_token(l_text) == "program":
            l_count += 1
    return l_count


def main() -> int:
    l_repo_root = Path(__file__).resolve().parents[3]
    l_failed = False

    print("[LAYOUT-GUARD] top-level program entry counts")
    for l_rel, l_limit in LIMITS.items():
        l_dir = l_repo_root / l_rel
        l_count = count_top_level_programs(l_dir)
        print(f"  - {l_rel}: count={l_count} limit={l_limit}")
        if l_count > l_limit:
            print(f"[LAYOUT-GUARD] FAILED: {l_rel} exceeded limit {l_limit} with {l_count} top-level programs")
            l_failed = True

    if l_failed:
        return 1

    print("[LAYOUT-GUARD] OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

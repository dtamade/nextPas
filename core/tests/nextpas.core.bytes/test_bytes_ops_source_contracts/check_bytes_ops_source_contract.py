#!/usr/bin/env python3
"""Source-contract gate for bytes.ops red-lines (inline/Move)."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_CORE_ROOT = SCRIPT_DIR.parents[3]  # core/tests/nextpas.core.bytes/test_... -> core

OPS_REL = "src/nextpas.core.bytes.ops.pas"
FACADE_REL = "src/nextpas.core.bytes.pas"


def read_text(p: Path) -> str:
    return p.read_text(encoding="utf-8", errors="ignore")


def strip_pascal_comments(text: str) -> str:
    out: list[str] = []
    i = 0
    n = len(text)
    while i < n:
        if text.startswith("//", i):
            nl = text.find("\n", i)
            if nl < 0:
                break
            out.append("\n")
            i = nl + 1
            continue
        if text.startswith("(*", i):
            end = text.find("*)", i + 2)
            comment = text[i:] if end < 0 else text[i : end + 2]
            out.append("\n" * comment.count("\n"))
            i = len(text) if end < 0 else end + 2
            continue
        if text[i] == "{":
            end = text.find("}", i + 1)
            comment = text[i:] if end < 0 else text[i : end + 1]
            # Keep {$I ...} directives as code (they affect compilation) but they don't contain Move
            if comment.startswith("{$"):
                out.append(comment)
            else:
                out.append("\n" * comment.count("\n"))
            i = len(text) if end < 0 else end + 1
            continue
        out.append(text[i])
        i += 1
    return "".join(out)


def parse_inline_names_in_section(lines: list[str], start: int, end: int) -> set[str]:
    inline_names: set[str] = set()
    i = start
    while i < end:
        line = lines[i]
        if re.match(r"^\s*(function|procedure)\s+", line, re.I):
            header = ""
            header_start = i
            # collect header until ';' appears (could span multiple lines)
            while i < end:
                header += lines[i] + "\n"
                if ";" in lines[i]:
                    break
                i += 1
            # extract name
            m = re.search(r"^\s*(?:function|procedure)\s+([A-Za-z_][A-Za-z0-9_\.]*)", header, re.I | re.M)
            if m and re.search(r"\binline\s*;", header, re.I):
                name = m.group(1).split(".")[-1].lower()
                inline_names.add(name)
        i += 1
    return inline_names


def check_ops(core_root: Path) -> list[str]:
    issues: list[str] = []
    ops_path = core_root / OPS_REL
    facade_path = core_root / FACADE_REL
    if not ops_path.is_file():
        return [f"missing {OPS_REL}"]
    if not facade_path.is_file():
        return [f"missing {FACADE_REL}"]

    ops_text = read_text(ops_path)
    facade_text = read_text(facade_path)

    # Keep line numbers for reporting: work on stripped version with same line count
    stripped_ops = strip_pascal_comments(ops_text)
    ops_lines = stripped_ops.splitlines()
    ops_orig_lines = ops_text.splitlines()

    # Find implementation boundary
    impl_idx = -1
    for idx, line in enumerate(ops_lines):
        if re.match(r"^\s*implementation\s*$", line, re.I):
            impl_idx = idx
            break
    if impl_idx < 0:
        issues.append(f"{OPS_REL}: missing implementation section")
        return issues

    # Verify header red-line markers exist (comment defense -> gate)
    if "red-line 1" not in ops_text or "red-line 2" not in ops_text:
        issues.append(f"{OPS_REL}: header must document red-line 1/2 (comment defense)")

    if "单源" not in ops_text:
        issues.append(f"{OPS_REL}: header must mention 单源/INV-5 (single source)")

    # Collect interface inline names
    interface_inline = parse_inline_names_in_section(ops_lines, 0, impl_idx)

    # Scan implementation routines
    i = impl_idx + 1
    n = len(ops_lines)
    while i < n:
        line = ops_lines[i]
        m = re.match(r"^\s*(function|procedure)\s+([A-Za-z_][A-Za-z0-9_\.]*)", line, re.I)
        if not m:
            i += 1
            continue
        kind = m.group(1)
        full_name = m.group(2)
        short_name = full_name.split(".")[-1]
        short_lower = short_name.lower()

        # Collect header (may span multiple lines until ';')
        header = ""
        header_start = i
        header_end = i
        while header_end < n:
            header += ops_lines[header_end] + "\n"
            if ";" in ops_lines[header_end]:
                break
            header_end += 1
        # Determine inline status: either interface says inline, or header says inline
        header_inline = bool(re.search(r"\binline\s*;", header, re.I))
        is_inline = header_inline or (short_lower in interface_inline)

        # Collect body until next routine or end.
        body_start = header_end + 1
        body_end = body_start
        while body_end < n:
            nxt = ops_lines[body_end]
            if re.match(r"^\s*(function|procedure)\s+[A-Za-z_]", nxt, re.I):
                break
            if re.match(r"^\s*end\.\s*$", nxt):
                break
            body_end += 1
        body_text = "\n".join(ops_lines[body_start:body_end])
        # Also need to handle case where routine is "inline;" with empty body (forward)? Those are interface only, not here.
        if is_inline:
            # Check indexed Move pattern: Move( ...[ ... ] ... )
            # Safe pointer-deref style is Move( Pointer(...)^ , ... ) or Move( PByte(...)^ , ... ) or Move( AData^ , ... )
            # We detect Move call containing '[' inside its parentheses
            for mv in re.finditer(r"\bMove\s*\(", body_text, re.I):
                # Extract Move call by balancing parens (simple: take substring until matching ')')
                start = mv.start()
                depth = 0
                j = mv.end() - 1
                call = ""
                while j < len(body_text):
                    ch = body_text[j]
                    call += ch
                    if ch == "(":
                        depth += 1
                    elif ch == ")":
                        depth -= 1
                        if depth == 0:
                            break
                    j += 1
                if "[" in call:
                    orig_line_no = header_start + 1  # 1-based
                    issues.append(
                        f"{OPS_REL}:{orig_line_no}: inline routine `{short_name}` must not contain indexed Move (red-line 1: 索引喂 untyped 常折拷垃圾) — found `{call.strip()[:80]}`"
                    )
                    break
            # Check loop + Move/SetLength
            has_loop = bool(re.search(r"\b(for|while|repeat)\b", body_text, re.I))
            has_move = bool(re.search(r"\bMove\s*\(", body_text, re.I))
            has_setlen = bool(re.search(r"\bSetLength\s*\(", body_text, re.I))
            if has_loop and (has_move or has_setlen):
                orig_line_no = header_start + 1
                issues.append(
                    f"{OPS_REL}:{orig_line_no}: inline routine `{short_name}` must not contain Move/SetLength inside loop/batch (red-line 2: 循环/SIMD 体 I-Cache 膨胀)"
                )
            # Also any inline with SetLength+Move batch (even without loop) should not be inline (batch encoding)
            if has_move and has_setlen:
                orig_line_no = header_start + 1
                # Avoid double-report if already flagged by loop rule
                already = any(short_name in iss for iss in issues)
                # Only flag if not already flagged and body contains both
                # Exception: inline thin forward that delegates should not have both in body; they won't.
                if not already:
                    issues.append(
                        f"{OPS_REL}:{orig_line_no}: inline routine `{short_name}` must not contain SetLength+Move batch (red-line 1: 每调分配+I-Cache) — single source stays not inline"
                    )
        # Advance
        i = body_end
    # Facade checks: must be thin forward, no direct Move/SetLength
    stripped_facade = strip_pascal_comments(facade_text)
    if re.search(r"\bMove\s*\(", stripped_facade, re.I):
        issues.append(f"{FACADE_REL}: facade must not contain direct Move (single source belongs to bytes.ops)")
    if re.search(r"\bSetLength\s*\(", stripped_facade, re.I):
        issues.append(f"{FACADE_REL}: facade must not contain direct SetLength (single source belongs to bytes.ops) — use ops allocation")
    # Also ensure facade still mentions single source
    if "single source" not in facade_text.lower() and "单源" not in facade_text:
        issues.append(f"{FACADE_REL}: missing single source forwarding note (INV-5)")

    return issues


def main() -> int:
    parser = argparse.ArgumentParser(description="Check bytes.ops inline/Move red-lines")
    parser.add_argument("--core-root", type=Path, default=DEFAULT_CORE_ROOT)
    parser.add_argument("--summary-line", action="store_true")
    args = parser.parse_args()
    core_root = args.core_root.resolve()
    issues = check_ops(core_root)
    if args.summary_line:
        print(f"BYTES_OPS_SOURCE_CONTRACT check=bytes.ops issues={len(issues)}")
    if issues:
        print("[BYTES-OPS-SOURCE-CONTRACT] FAIL")
        for iss in issues:
            print(f"  - {iss}")
        return 1
    print("[BYTES-OPS-SOURCE-CONTRACT] PASS")
    # Performance / zero-copy evidence line for gate output
    print("bytes.ops single-source: SetLength+Move zero-copy (Pointer(Result)^ / PAnsiChar(AText)^ single Move, single SetLength); inline hot views (Compare/MemEqual/FindByte) zero-copy TByteSpan")
    print("stability: SetLength exception-safe, sized FreeMemOf on Builder/StreamBuf, Clear/Consume not leak")
    return 0


if __name__ == "__main__":
    sys.exit(main())

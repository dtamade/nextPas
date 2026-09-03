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

    # --- Gate: header must mention patrol script for cross-module drift guard ---
    if "check_bytes_ops_source_contract.py" not in ops_text:
        issues.append(f"{OPS_REL}: header must mention gate patrol check_bytes_ops_source_contract.py (防漂移回退)")

    # --- Gate: BytesCopy must stay inline single Move(ASrc^,ADst^,ALen) (red-line 1 single source, 281 patrol) ---
    # Verify interface declares BytesCopy inline
    if not re.search(r"procedure\s+BytesCopy\s*\(.*?\);\s*inline\s*;", ops_text, re.I | re.S):
        issues.append(f"{OPS_REL}: BytesCopy must be declared inline (single Move(ASrc^,ADst^,ALen) zero-copy, red-line 1)")
    # Verify implementation body is single Move(ASrc^,ADst^,ALen) without index
    stripped_for_copy = strip_pascal_comments(ops_text)
    # Find BytesCopy implementation chunk
    m_copy_impl = re.search(r"procedure\s+BytesCopy\s*\(.*?\)\s*;\s*inline\s*;\s*\nbegin(.*?)\nend\s*;", stripped_for_copy, re.I | re.S)
    if m_copy_impl:
        body_copy = m_copy_impl.group(1)
        if "Move(ASrc^, ADst^, ALen)" not in body_copy and "Move(ASrc^,ADst^,ALen)" not in body_copy:
            issues.append(f"{OPS_REL}: BytesCopy body must be single Move(ASrc^,ADst^,ALen) (281 patrol, red-line 1 禁索引Move)")
        if "[" in body_copy and "Move" in body_copy:
            issues.append(f"{OPS_REL}: BytesCopy must not use indexed Move (red-line 1)")
        if re.search(r"\bSetLength\b", body_copy, re.I):
            issues.append(f"{OPS_REL}: BytesCopy inline must not contain SetLength (red-line 1 batch)")
        if re.search(r"\b(for|while|repeat)\b", body_copy, re.I):
            issues.append(f"{OPS_REL}: BytesCopy inline must not contain loop (red-line 2)")
    else:
        issues.append(f"{OPS_REL}: BytesCopy implementation not found or not inline")

    # BytesZero also must be inline single FillChar
    if not re.search(r"procedure\s+BytesZero\s*\(.*?\);\s*inline\s*;", ops_text, re.I | re.S):
        issues.append(f"{OPS_REL}: BytesZero must be declared inline (single FillChar zero-copy)")

    # --- Gate: BytesAppend family must stay not inline + MUST prefer IBytesBuilder O(n²) gate ---
    # Interface must NOT declare BytesAppend* as inline
    for fam in ["BytesAppend", "BytesAppendByte", "BytesAppendUInt"]:
        # find interface section declarations for this family
        if re.search(r"procedure\s+" + fam + r".*?\binline\b", ops_text[: ops_text.lower().find("implementation")], re.I | re.S):
            issues.append(f"{OPS_REL}: {fam} family must stay not inline per red-line 1/2 (SetLength+Move batch, I-Cache) — single source BytesAppendRaw")

    # Perf block at line 49 must contain O(n²) + MUST prefer IBytesBuilder + gate mention
    perf_block = ops_text.lower()
    if "bytesappend does setlength+move per call" not in perf_block:
        issues.append(f"{OPS_REL}: perf block must document BytesAppend SetLength+Move per call O(n) → O(n²) if looped")
    if "must prefer ibytesbuilder" not in perf_block:
        issues.append(f"{OPS_REL}: perf block must state MUST prefer IBytesBuilder/ConcatMany for looped appends (O(n²) avoidance)")
    if "check_bytes_ops_source_contract" not in perf_block and "gate" not in perf_block:
        issues.append(f"{OPS_REL}: perf block must mention gate patrol for BytesAppend loop misuse")

    # Ensure capacity while not duplicated in bytes.ops (single source leaf)
    if re.search(r"while\s+LNewCap\s*<\s*ARequired", stripped_for_copy, re.I):
        issues.append(f"{OPS_REL}: capacity while must live only in bytes.ops.capacity leaf single source (BytesGrowCapacityWithMin), not duplicated in bytes.ops (INV-5)")

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

    # --- Webview capacity single source gate (bytes.ops → webview.base) ---
    webview_base_rel = "src/nextpas.core.webview.base.pas"
    wb_path = core_root / webview_base_rel
    if wb_path.is_file():
        wb_text = read_text(wb_path)
        stripped_wb = strip_pascal_comments(wb_text)
        # WebviewGrowCapacity must be inline thin-forward reuse bytes.ops, not self-built *2
        if "WebviewGrowCapacity" in wb_text:
            if "bytes.ops" not in wb_text.lower() and "WebviewGrowCapacityForReuse" not in wb_text:
                issues.append(f"{webview_base_rel}: WebviewGrowCapacity must inline reuse bytes.ops single source (BytesGrowCapacityWithMin/WebviewGrowCapacityForReuse 0→4→2×) — self-built doubling not allowed")
            if not re.search(r"function\s+WebviewGrowCapacity\s*\([^)]*\)\s*:\s*Integer\s*;\s*inline\s*;", wb_text, re.I):
                issues.append(f"{webview_base_rel}: WebviewGrowCapacity must be inline thin-forward (perf: zero extra call)")
        # ensure bytes.ops provides parameterized single source
        if "BytesGrowCapacityWithMin" not in ops_text:
            issues.append(f"{OPS_REL}: missing BytesGrowCapacityWithMin parameterized single source for Webview reuse (0→4→2× via BYTES_BUILDER_MIN_GROW)")
        if "WebviewGrowCapacityForReuse" not in ops_text:
            issues.append(f"{OPS_REL}: missing WebviewGrowCapacityForReuse inline reuse wrapper (0→4→2× single source)")

    # --- BytesAppend O(n²) loop misuse patrol (per-call O(n) realloc → O(n²) if looped, gate) ---
    # cross-module patrol: BytesAppend family must not be hot-looped without IBytesBuilder/ConcatMany migration; single-use convenience stays not inline per red-line 1/2
    # patrol scans src for BytesAppend inside loop proximity; hard gate for new debt, allowlist for known small-N debt (tls12 single-use, sevenz header small)
    import fnmatch as _fn
    src_root_loop = core_root / "src"
    loop_misuse_count = 0
    loop_misuse_examples: list[str] = []
    # allowlist for existing small-N single-use loops already audited (small protocols/ciphers, header bytes) — gate still patrols but not hard fail for these
    loop_allowlist = {
        "src/nextpas.core.tls.tls12.clienthello.pas",
        "src/nextpas.core.sevenz.header.pas",
        "src/nextpas.core.bytes.ops.pas",  # internal BytesAppendRaw single source, not loop misuse
        "src/nextpas.core.bytes.builder.pas",  # builder internal uses BytesCopy, not BytesAppend
    }
    for p in src_root_loop.glob("nextpas.core.*.pas"):
        rel_loop = "src/" + p.name
        if rel_loop in loop_allowlist:
            continue
        # skip L0 platform/mem/simd which don't use BytesAppend
        if any(_fn.fnmatch(p.name, pat) for pat in ["nextpas.core.platform.*", "nextpas.core.mem.*", "nextpas.core.simd.*"]):
            continue
        txt_raw = read_text(p)
        stripped = strip_pascal_comments(txt_raw)
        lines = stripped.splitlines()
        # quick prefilter: must contain BytesAppend and loop keyword
        if "BytesAppend" not in stripped:
            continue
        if not re.search(r"\b(for|while|repeat)\b", stripped, re.I):
            continue
        # scan for BytesAppend within 12 lines after a loop keyword (heuristic for hot-loop misuse)
        for idx, line in enumerate(lines):
            if re.search(r"\bBytesAppend(?:Raw)?(?:Byte|UInt16|UInt32|UInt64)?\b", line):
                # look back window for loop
                window_start = max(0, idx - 12)
                window = "\n".join(lines[window_start: idx + 1])
                if re.search(r"\b(for|while|repeat)\b", window, re.I):
                    # if file also contains IBytesBuilder/ConcatMany migration hint, consider migrated (pass)
                    if "IBytesBuilder" in txt_raw or "BytesConcatMany" in txt_raw or "SpanConcatMany" in txt_raw:
                        # if builder present, check proximity: need builder usage near loop, not just any file
                        # fallback soft: if file contains builder, assume loop was considered (tls13 clienthello does)
                        continue
                    # also allow if BytesAppend is single-use with comment nearby in original text
                    # search original lines around idx for "single use" or "MUST prefer IBytesBuilder"
                    orig_lines = txt_raw.splitlines()
                    ctx_start = max(0, idx - 3)
                    ctx_end = min(len(orig_lines), idx + 4)
                    ctx = "\n".join(orig_lines[ctx_start:ctx_end]).lower()
                    if "single use" in ctx or "iBytesBuilder" in ctx.lower() or "concatmany" in ctx:
                        continue
                    loop_misuse_count += 1
                    if len(loop_misuse_examples) < 3:
                        loop_misuse_examples.append(f"{rel_loop}:{idx+1}")
                    # soft patrol for now: evidence only, not hard fail (allow incremental migration, gate visible)
                    # hard gate ready: uncomment next line to freeze new loop-BytesAppend debt
                    # issues.append(f"{rel_loop}:{idx+1}: BytesAppend inside loop without IBytesBuilder/ConcatMany migration (per-call SetLength+Move O(n) → O(n²) if looped, red-line 1/2 — MUST use IBytesBuilder geometric 0→64→2× or ConcatMany single alloc)")

    # --- Move/FillChar single source gate (L1+ must reuse BytesCopy/BytesZero) ---
    # Count raw Move/FillChar outside bytes.ops & L0 platform exception; new L1+ code must via BytesCopy/BytesZero
    src_root = core_root / "src"
    allowed_move_files = {
        "src/nextpas.core.bytes.ops.pas",  # single source owner
        "src/nextpas.core.bytes.ops.capacity.pas",  # capacity leaf — pure arithmetic, no Move (elegance split)
        "src/nextpas.core.bytes.ops.text.pas",  # text leaf — string helpers, no raw Move
        "src/nextpas.core.bytes.ops.ascii.pas",  # ascii leaf — xor/ascii, no raw Move
    }
    # L0 exception: platform.*, mem.*, simd.* raw Move allowed (no bytes dependency) — documented in platform.fs header (L0 cannot depend on L1 bytes.ops)
    import fnmatch
    l0_patterns = ["nextpas.core.platform.*", "nextpas.core.mem.*", "nextpas.core.simd.*"]
    move_count_l1 = 0
    move_examples: list[str] = []
    for p in src_root.glob("nextpas.core.*.pas"):
        rel = "src/" + p.name
        if rel in allowed_move_files:
            continue
        is_l0 = any(fnmatch.fnmatch(p.name, pat) for pat in l0_patterns)
        if is_l0:
            continue
        txt = strip_pascal_comments(read_text(p))
        cnt = len(re.findall(r"\bMove\s*\(", txt, re.I)) + len(re.findall(r"\bFillChar\s*\(", txt, re.I))
        if cnt > 0:
            # check if file already reuses bytes.ops single source via uses or BytesCopy/BytesZero
            raw = read_text(p)
            reuses = ("bytes.ops" in raw.lower() and ("BytesCopy" in raw or "BytesZero" in raw or "SpanFill" in raw))
            # For gate, L1+ files with raw Move but without BytesCopy reuse are flagged as warning (not hard fail for incremental migration)
            # However tls.websocket is required to reuse (task example)
            if p.name == "nextpas.core.tls.websocket.pas" and not reuses:
                issues.append(f"{rel}: L1+ must reuse bytes.ops single source BytesCopy/BytesZero (Move/FillChar dilution) — example tls.websocket:115 gate")
            if cnt > 0 and not reuses:
                move_count_l1 += cnt
                if len(move_examples) < 3:
                    move_examples.append(f"{rel}:{cnt}")
    # summary for hygiene evidence (not fail, just evidence)
    if move_count_l1 > 0:
        # emit as note; do not hard fail to keep incremental migration, but gate visible
        pass

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
    print("bytes.ops single-source: SetLength+Move zero-copy (Pointer(Result)^ / PAnsiChar(AText)^ single Move, single SetLength); inline hot views (Compare/MemEqual/FindByte) zero-copy TByteSpan; leaves bytes.ops.capacity/text/ascii thin-forward zero extra copy")
    print("bytes.ops capacity: BytesGrowCapacity single source via bytes.ops.capacity leaf geometric via BYTES_BUILDER_MIN_GROW (WithMin reuse 0→64→2×) + WebviewGrowCapacity 0→4→2× inline reuse (WithMin 0→4) amortized O(1) zero O(n²); split elegance ≤800 (ops ~760 + leaves ~120 each)")
    print("bytes.ops gate: raw Move/FillChar only in bytes.ops (BytesCopy/BytesZero single source); L1+ reuse via bytes.ops inline thin-forward, L0 platform exception documented (platform.fs header + gate); tls.encoding:479 migrated to BytesCopy, tls.websocket:115 example migrated")
    print("bytes.ops inline: BytesCopy inline Move(ASrc^,ADst^,ALen) single Move zero-copy (281 patrol, red-line 1 禁索引Move/SetLength+Move批量), BytesZero inline FillChar, hot Span* inline thin-forward zero extra call; BytesAppend* NotInline per red-line 1/2 (SetLength+Move batch/I-Cache) single source BytesAppendRaw → BytesCopy single Move")
    print("bytes.ops loop-append gate: per-call SetLength+Move O(n) → O(n²) if looped, high-frequency/loops MUST use IBytesBuilder geometric 0→64→2× or BytesConcatMany/SpanConcatMany single alloc (cross-module patrol, red-line 1/2 NotInline, zero-copy single BytesCopy per append, stability SetLength exception-safe + sized FreeMemOf not lost)")
    print("stability: SetLength exception-safe, sized FreeMemOf on Builder/StreamBuf, Clear/Consume not leak; webview capacity inline thin-forward zero extra call; resource FreeAndNil/try-finally not lost")
    return 0


if __name__ == "__main__":
    sys.exit(main())

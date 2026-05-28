#!/usr/bin/env python3
"""Check that direct SIMD dispatch reads stay in internal source units."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path


SYMBOL = "GetDispatchTable"
SUMMARY_PREFIX = "DISPATCH_READ_SCOPE"
SCAN_GLOBS = (
    "src/nextpas.core.simd*.pas",
    "src/nextpas.core.simd*.inc",
)
ALLOWED_DIRECT_READ_FILES = {
    "src/nextpas.core.simd.dispatch.pas",
    "src/nextpas.core.simd.dataplane.pas",
    "src/nextpas.core.simd.runtime.pas",
}
SYMBOL_RE = re.compile(rf"\b{re.escape(SYMBOL)}\b")
ACTIVE_PUBLIC_ABI_DOC = "docs/nextpas.core.simd.publicabi.md"
FACADE_SOURCE_FILE = "src/nextpas.core.simd.pas"
FACADE_FORBIDDEN_GETTER_SYMBOL = "GetCurrentSimdDataPlaneDispatch"
PUBLIC_ABI_DOC_FORBIDDEN_PATTERNS = (
    re.compile(r"\u515c\u5e95.{0,80}dispatch table", re.IGNORECASE),
    re.compile(r"fallback.{0,80}dispatch table", re.IGNORECASE),
)
PUBLIC_ABI_DOC_REQUIRED_FRAGMENTS = (
    "published `dataplane`",
    "`public ABI wrapper`",
    "`GetDispatchTable`",
)
FACADE_FORBIDDEN_GETTER_RE = re.compile(
    rf"\b{re.escape(FACADE_FORBIDDEN_GETTER_SYMBOL)}\b"
)
FACADE_REQUIRED_FRAGMENTS = (
    "g_FastSimdDispatchPtr",
    "function GetSimdFacadeDispatchFastPath",
    "LDataPlane^.Dispatch",
    "atomic_store(g_FastSimdDispatchPtr, nil",
)


@dataclass(frozen=True)
class Hit:
    path: str
    line: int
    text: str


@dataclass(frozen=True)
class Report:
    symbol: str
    repo_root: str
    scan_globs: list[str]
    allowed_files: list[str]
    scanned_files: int
    allowed_hits: list[Hit]
    forbidden_hits: list[Hit]
    active_doc_issues: list[str]
    facade_issues: list[str]

    @property
    def ok(self) -> bool:
        return (
            len(self.forbidden_hits) == 0
            and len(self.active_doc_issues) == 0
            and len(self.facade_issues) == 0
        )


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Check that GetDispatchTable is only read by SIMD control/"
            "publication internals."
        )
    )
    parser.add_argument(
        "--root",
        default=str(repo_root()),
        help="Repository root to scan. Defaults to this script's repository.",
    )
    parser.add_argument(
        "--json-file",
        help="Optional path to write a machine-readable report.",
    )
    parser.add_argument(
        "--summary-line",
        action="store_true",
        help="Print a one-line summary for runner logs.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print allowed hits as well as forbidden hits.",
    )
    return parser.parse_args()


def strip_pascal_comments_and_strings(aText: str) -> str:
    """Replace Pascal comments/strings with spaces while preserving lines."""

    l_out: list[str] = []
    l_index = 0
    l_len = len(aText)
    l_in_string = False
    l_in_line_comment = False
    l_in_brace_comment = False
    l_in_paren_star_comment = False

    while l_index < l_len:
        l_char = aText[l_index]
        l_next = aText[l_index + 1] if l_index + 1 < l_len else ""

        if l_in_string:
            if l_char == "'" and l_next == "'":
                l_out.extend("  ")
                l_index += 2
                continue
            if l_char == "'":
                l_in_string = False
            l_out.append("\n" if l_char == "\n" else " ")
            l_index += 1
            continue

        if l_in_line_comment:
            if l_char == "\n":
                l_in_line_comment = False
                l_out.append("\n")
            else:
                l_out.append(" ")
            l_index += 1
            continue

        if l_in_brace_comment:
            if l_char == "}":
                l_in_brace_comment = False
            l_out.append("\n" if l_char == "\n" else " ")
            l_index += 1
            continue

        if l_in_paren_star_comment:
            if l_char == "*" and l_next == ")":
                l_in_paren_star_comment = False
                l_out.extend("  ")
                l_index += 2
                continue
            l_out.append("\n" if l_char == "\n" else " ")
            l_index += 1
            continue

        if l_char == "'":
            l_in_string = True
            l_out.append(" ")
            l_index += 1
            continue

        if l_char == "/" and l_next == "/":
            l_in_line_comment = True
            l_out.extend("  ")
            l_index += 2
            continue

        if l_char == "{":
            l_in_brace_comment = True
            l_out.append(" ")
            l_index += 1
            continue

        if l_char == "(" and l_next == "*":
            l_in_paren_star_comment = True
            l_out.extend("  ")
            l_index += 2
            continue

        l_out.append(l_char)
        l_index += 1

    return "".join(l_out)


def discover_source_files(aRoot: Path) -> list[Path]:
    l_files: set[Path] = set()
    for l_glob in SCAN_GLOBS:
        l_files.update(aRoot.glob(l_glob))
    return sorted(l_path for l_path in l_files if l_path.is_file())


def scan_file(aRoot: Path, aPath: Path) -> list[Hit]:
    l_text = aPath.read_text(encoding="utf-8", errors="replace")
    l_stripped = strip_pascal_comments_and_strings(l_text)
    l_original_lines = l_text.splitlines()
    l_stripped_lines = l_stripped.splitlines()
    l_hits: list[Hit] = []
    l_rel = aPath.relative_to(aRoot).as_posix()

    for l_line_no, (l_original, l_code) in enumerate(
        zip(l_original_lines, l_stripped_lines),
        start=1,
    ):
        if SYMBOL_RE.search(l_code):
            l_hits.append(Hit(path=l_rel, line=l_line_no, text=l_original.strip()))

    return l_hits


def build_report(aRoot: Path) -> Report:
    l_files = discover_source_files(aRoot)
    l_allowed_hits: list[Hit] = []
    l_forbidden_hits: list[Hit] = []
    l_active_doc_issues = check_active_public_abi_doc(aRoot)
    l_facade_issues = check_facade_hot_path_mirror(aRoot)

    for l_path in l_files:
        l_rel = l_path.relative_to(aRoot).as_posix()
        l_hits = scan_file(aRoot, l_path)
        if l_rel in ALLOWED_DIRECT_READ_FILES:
            l_allowed_hits.extend(l_hits)
        else:
            l_forbidden_hits.extend(l_hits)

    return Report(
        symbol=SYMBOL,
        repo_root=str(aRoot),
        scan_globs=list(SCAN_GLOBS),
        allowed_files=sorted(ALLOWED_DIRECT_READ_FILES),
        scanned_files=len(l_files),
        allowed_hits=l_allowed_hits,
        forbidden_hits=l_forbidden_hits,
        active_doc_issues=l_active_doc_issues,
        facade_issues=l_facade_issues,
    )


def check_active_public_abi_doc(aRoot: Path) -> list[str]:
    l_path = aRoot / ACTIVE_PUBLIC_ABI_DOC
    if not l_path.is_file():
        return [f"missing active public ABI doc: {ACTIVE_PUBLIC_ABI_DOC}"]

    l_text = l_path.read_text(encoding="utf-8", errors="replace")
    l_issues: list[str] = []
    for l_pattern in PUBLIC_ABI_DOC_FORBIDDEN_PATTERNS:
        l_match = l_pattern.search(l_text)
        if l_match:
            l_issues.append(
                f"{ACTIVE_PUBLIC_ABI_DOC}: stale dispatch fallback wording: "
                f"{l_match.group(0)}"
            )

    for l_fragment in PUBLIC_ABI_DOC_REQUIRED_FRAGMENTS:
        if l_fragment not in l_text:
            l_issues.append(
                f"{ACTIVE_PUBLIC_ABI_DOC}: missing required fragment: {l_fragment}"
            )

    return l_issues


def check_facade_hot_path_mirror(aRoot: Path) -> list[str]:
    l_path = aRoot / FACADE_SOURCE_FILE
    if not l_path.is_file():
        return [f"missing facade source file: {FACADE_SOURCE_FILE}"]

    l_text = l_path.read_text(encoding="utf-8", errors="replace")
    l_stripped = strip_pascal_comments_and_strings(l_text)
    l_issues: list[str] = []

    for l_line_no, l_code in enumerate(l_stripped.splitlines(), start=1):
        if FACADE_FORBIDDEN_GETTER_RE.search(l_code):
            l_issues.append(
                f"{FACADE_SOURCE_FILE}:{l_line_no}: facade hot path must use "
                "its local dataplane dispatch mirror, not "
                f"{FACADE_FORBIDDEN_GETTER_SYMBOL}"
            )

    for l_fragment in FACADE_REQUIRED_FRAGMENTS:
        if l_fragment not in l_stripped:
            l_issues.append(
                f"{FACADE_SOURCE_FILE}: missing facade dispatch mirror "
                f"fragment: {l_fragment}"
            )

    return l_issues


def print_human_report(aReport: Report, aVerbose: bool) -> None:
    if aReport.forbidden_hits:
        for l_hit in aReport.forbidden_hits:
            print(
                "[DISPATCH-READ-SCOPE] FORBIDDEN "
                f"{l_hit.path}:{l_hit.line}: {l_hit.text}"
            )
    elif aVerbose:
        print("[DISPATCH-READ-SCOPE] No forbidden direct dispatch reads found.")

    if aVerbose:
        for l_hit in aReport.allowed_hits:
            print(
                "[DISPATCH-READ-SCOPE] allowed "
                f"{l_hit.path}:{l_hit.line}: {l_hit.text}"
            )

    for l_issue in aReport.active_doc_issues:
        print(f"[DISPATCH-READ-SCOPE] DOC-ISSUE {l_issue}")

    for l_issue in aReport.facade_issues:
        print(f"[DISPATCH-READ-SCOPE] FACADE-ISSUE {l_issue}")

    if aReport.ok:
        print("[DISPATCH-READ-SCOPE] OK")
    else:
        print(
            "[DISPATCH-READ-SCOPE] FAILED: GetDispatchTable is only allowed in "
            "dispatch/dataplane/runtime internals, and active public ABI docs "
            "must describe dataplane fallback semantics. The main facade must "
            "also use its local dataplane dispatch mirror."
        )


def render_summary_line(aReport: Report) -> str:
    return (
        f"{SUMMARY_PREFIX} "
        f"symbol={aReport.symbol} "
        f"scanned_files={aReport.scanned_files} "
        f"allowed_files={len(aReport.allowed_files)} "
        f"allowed_hits={len(aReport.allowed_hits)} "
        f"forbidden_hits={len(aReport.forbidden_hits)} "
        f"active_doc_issues={len(aReport.active_doc_issues)} "
        f"facade_issues={len(aReport.facade_issues)}"
    )


def main() -> int:
    l_args = parse_args()
    l_root = Path(l_args.root).resolve()

    if not l_root.exists():
        print(f"[DISPATCH-READ-SCOPE] Missing root: {l_root}")
        return 2

    try:
        l_report = build_report(l_root)
    except RuntimeError as l_exc:
        print(f"[DISPATCH-READ-SCOPE] ERROR: {l_exc}")
        return 2

    if l_args.json_file:
        l_json_path = Path(l_args.json_file)
        l_json_path.parent.mkdir(parents=True, exist_ok=True)
        l_json_path.write_text(
            json.dumps(asdict(l_report), ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        print(f"[DISPATCH-READ-SCOPE] JSON snapshot: {l_json_path}")

    print_human_report(l_report, l_args.verbose)

    if l_args.summary_line:
        print(render_summary_line(l_report))

    return 0 if l_report.ok else 1


if __name__ == "__main__":
    sys.exit(main())

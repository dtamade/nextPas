#!/usr/bin/env python3
"""Guard direct dispatch reads from leaking past sanctioned companion surfaces."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path


SUMMARY_PREFIX = "DIRECT_DISPATCH_SCOPE"
SYMBOL = "GetDirectDispatchTable"
SCAN_GLOBS = (
    "src/nextpas.core.simd*.pas",
    "src/nextpas.core.simd*.inc",
)
ALLOWED_FILES = {
    "src/nextpas.core.simd.algorithms.pas",
    "src/nextpas.core.simd.api.pas",
    "src/nextpas.core.simd.arrays.pas",
    "src/nextpas.core.simd.direct.pas",
    "src/nextpas.core.simd.ops.pas",
}
SYMBOL_RE = re.compile(rf"\b{re.escape(SYMBOL)}\b")


@dataclass(frozen=True)
class Hit:
    path: str
    line: int
    text: str


@dataclass(frozen=True)
class Report:
    repo_root: str
    symbol: str
    scan_globs: list[str]
    allowed_files: list[str]
    scanned_files: int
    allowed_hits: list[Hit]
    forbidden_hits: list[Hit]

    @property
    def ok(self) -> bool:
        return len(self.forbidden_hits) == 0


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def parse_args() -> argparse.Namespace:
    l_parser = argparse.ArgumentParser(
        description=(
            "Check that GetDirectDispatchTable only stays in direct companion "
            "surfaces."
        )
    )
    l_parser.add_argument(
        "--root",
        default=str(repo_root()),
        help="Repository root to scan. Defaults to this script's repository.",
    )
    l_parser.add_argument(
        "--json-file",
        help="Optional path to write a machine-readable report.",
    )
    l_parser.add_argument(
        "--summary-line",
        action="store_true",
        help="Print a one-line summary for runner logs.",
    )
    l_parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print allowed hits as well as forbidden hits.",
    )
    return l_parser.parse_args()


def strip_pascal_comments_and_strings(a_text: str) -> str:
    """Replace Pascal comments/strings with spaces while preserving lines."""

    l_out: list[str] = []
    l_index = 0
    l_len = len(a_text)
    l_in_string = False
    l_in_line_comment = False
    l_in_brace_comment = False
    l_in_paren_star_comment = False

    while l_index < l_len:
        l_char = a_text[l_index]
        l_next = a_text[l_index + 1] if l_index + 1 < l_len else ""

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


def discover_source_files(a_root: Path) -> list[Path]:
    l_files: set[Path] = set()
    for l_glob in SCAN_GLOBS:
        l_files.update(a_root.glob(l_glob))
    return sorted(l_path for l_path in l_files if l_path.is_file())


def scan_file(a_root: Path, a_path: Path) -> list[Hit]:
    l_text = a_path.read_text(encoding="utf-8", errors="replace")
    l_stripped = strip_pascal_comments_and_strings(l_text)
    l_original_lines = l_text.splitlines()
    l_stripped_lines = l_stripped.splitlines()
    l_rel = a_path.relative_to(a_root).as_posix()
    l_hits: list[Hit] = []

    for l_line_no, (l_original, l_code) in enumerate(
        zip(l_original_lines, l_stripped_lines),
        start=1,
    ):
        if SYMBOL_RE.search(l_code):
            l_hits.append(
                Hit(
                    path=l_rel,
                    line=l_line_no,
                    text=l_original.strip(),
                )
            )

    return l_hits


def build_report(a_root: Path) -> Report:
    l_files = discover_source_files(a_root)
    l_allowed_hits: list[Hit] = []
    l_forbidden_hits: list[Hit] = []

    for l_path in l_files:
        for l_hit in scan_file(a_root, l_path):
            if l_hit.path in ALLOWED_FILES:
                l_allowed_hits.append(l_hit)
            else:
                l_forbidden_hits.append(l_hit)

    return Report(
        repo_root=str(a_root),
        symbol=SYMBOL,
        scan_globs=list(SCAN_GLOBS),
        allowed_files=sorted(ALLOWED_FILES),
        scanned_files=len(l_files),
        allowed_hits=l_allowed_hits,
        forbidden_hits=l_forbidden_hits,
    )


def print_human_report(a_report: Report, a_verbose: bool) -> None:
    if a_report.forbidden_hits:
        for l_hit in a_report.forbidden_hits:
            print(
                "[DIRECT-SCOPE] FORBIDDEN "
                f"{l_hit.path}:{l_hit.line}: {l_hit.text}"
            )
    elif a_verbose:
        print("[DIRECT-SCOPE] No forbidden direct dispatch companion reads found.")

    if a_verbose:
        for l_hit in a_report.allowed_hits:
            print(
                "[DIRECT-SCOPE] allowed "
                f"{l_hit.path}:{l_hit.line}: {l_hit.text}"
            )

    if a_report.ok:
        print("[DIRECT-SCOPE] OK")
    else:
        print(
            "[DIRECT-SCOPE] FAILED: GetDirectDispatchTable must stay in "
            "api/arrays/ops/direct companion surfaces so other modules cannot "
            "grow a second direct fast-path boundary."
        )


def render_summary_line(a_report: Report) -> str:
    return (
        f"{SUMMARY_PREFIX} "
        f"symbol={a_report.symbol} "
        f"scanned_files={a_report.scanned_files} "
        f"allowed_files={len(a_report.allowed_files)} "
        f"allowed_hits={len(a_report.allowed_hits)} "
        f"forbidden_hits={len(a_report.forbidden_hits)}"
    )


def main() -> int:
    l_args = parse_args()
    l_root = Path(l_args.root).resolve()

    if not l_root.exists():
        print(f"[DIRECT-SCOPE] Missing root: {l_root}")
        return 2

    l_report = build_report(l_root)

    if l_args.json_file:
        l_json_path = Path(l_args.json_file)
        l_json_path.parent.mkdir(parents=True, exist_ok=True)
        l_json_path.write_text(
            json.dumps(asdict(l_report), ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        print(f"[DIRECT-SCOPE] JSON snapshot: {l_json_path}")

    print_human_report(l_report, l_args.verbose)

    if l_args.summary_line:
        print(render_summary_line(l_report))

    return 0 if l_report.ok else 1


if __name__ == "__main__":
    sys.exit(main())

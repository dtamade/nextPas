#!/usr/bin/env python3
"""Check that public SIMD facade/API declarations are referenced by test sources."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import asdict, dataclass
from datetime import datetime
from pathlib import Path


DECL_RE = re.compile(
    r"^\s*(?P<kind>function|procedure)\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)\b",
    re.IGNORECASE | re.MULTILINE,
)
IMPLEMENTATION_RE = re.compile(r"^\s*implementation\b.*$", re.IGNORECASE | re.MULTILINE)
TOKEN_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


@dataclass(frozen=True)
class SymbolCoverage:
    source: str
    kind: str
    name: str
    ref_count: int
    file_hits: int
    test_files: list[str]


def parse_args() -> argparse.Namespace:
    l_parser = argparse.ArgumentParser(
        description=(
            "Check that public SIMD facade/API/api.v2 declarations are covered "
            "by test source references across tests/nextpas.core.simd*."
        )
    )
    l_parser.add_argument("--json", action="store_true", help="print JSON payload")
    l_parser.add_argument(
        "--json-file",
        default="",
        help="write JSON payload to file",
    )
    l_parser.add_argument(
        "--md-file",
        default="",
        help="write markdown summary to file",
    )
    l_parser.add_argument(
        "--summary-line",
        action="store_true",
        help="print one-line summary for log scraping",
    )
    l_parser.add_argument(
        "--min-refs",
        type=int,
        default=2,
        help="treat symbols with fewer refs than this as thin coverage (default: 2)",
    )
    l_parser.add_argument(
        "--strict-thin",
        action="store_true",
        help="fail when thin coverage symbols exist",
    )
    return l_parser.parse_args()


def extract_interface_text(a_path: Path) -> str:
    l_text = a_path.read_text(encoding="utf-8", errors="ignore")
    l_masked = strip_pascal_non_code(l_text)
    l_match = IMPLEMENTATION_RE.search(l_masked)
    if l_match is None:
        return l_text
    return l_text[: l_match.start()]


def extract_symbols(a_repo_root: Path, a_path: Path) -> list[tuple[str, str, str]]:
    l_text = extract_interface_text(a_path)
    return [
        (
            str(a_path.relative_to(a_repo_root)).replace("\\", "/"),
            l_match.group("kind").lower(),
            l_match.group("name"),
        )
        for l_match in DECL_RE.finditer(l_text)
    ]


def normalize_symbol_name(a_name: str) -> str:
    return a_name.lower()


def mask_pascal_gap_char(a_char: str) -> str:
    if a_char in {"\n", "\r"}:
        return a_char
    return " "


def strip_pascal_non_code(a_text: str) -> str:
    l_chars = list(a_text)
    l_len = len(l_chars)
    l_idx = 0

    while l_idx < l_len:
        l_char = l_chars[l_idx]
        l_next = l_chars[l_idx + 1] if l_idx + 1 < l_len else ""

        if l_char == "'":
            l_chars[l_idx] = " "
            l_idx += 1
            while l_idx < l_len:
                l_char = l_chars[l_idx]
                l_next = l_chars[l_idx + 1] if l_idx + 1 < l_len else ""
                l_chars[l_idx] = mask_pascal_gap_char(l_char)
                if l_char == "'":
                    if l_next == "'":
                        l_chars[l_idx + 1] = " "
                        l_idx += 2
                        continue
                    l_idx += 1
                    break
                l_idx += 1
            continue

        if l_char == "{" and l_next != "$":
            l_chars[l_idx] = " "
            l_idx += 1
            while l_idx < l_len:
                l_char = l_chars[l_idx]
                l_chars[l_idx] = mask_pascal_gap_char(l_char)
                if l_char == "}":
                    l_idx += 1
                    break
                l_idx += 1
            continue

        if l_char == "(" and l_next == "*":
            l_chars[l_idx] = " "
            l_chars[l_idx + 1] = " "
            l_idx += 2
            while l_idx < l_len:
                l_char = l_chars[l_idx]
                l_next = l_chars[l_idx + 1] if l_idx + 1 < l_len else ""
                if l_char == "*" and l_next == ")":
                    l_chars[l_idx] = " "
                    l_chars[l_idx + 1] = " "
                    l_idx += 2
                    break
                l_chars[l_idx] = mask_pascal_gap_char(l_char)
                l_idx += 1
            continue

        if l_char == "/" and l_next == "/":
            l_chars[l_idx] = " "
            l_chars[l_idx + 1] = " "
            l_idx += 2
            while l_idx < l_len:
                l_char = l_chars[l_idx]
                if l_char in {"\n", "\r"}:
                    l_idx += 1
                    break
                l_chars[l_idx] = " "
                l_idx += 1
            continue

        l_idx += 1

    return "".join(l_chars)


def collect_test_files(a_repo_root: Path) -> list[Path]:
    l_tests_root = a_repo_root / "tests"
    l_files: list[Path] = []
    for l_dir in sorted(l_path for l_path in l_tests_root.glob("nextpas.core.simd*") if l_path.is_dir()):
        l_files.extend(sorted(l_dir.rglob("*.pas")))
    return l_files


def render_markdown(a_payload: dict) -> str:
    l_lines: list[str] = []
    l_lines.append("# SIMD Public API Test Coverage")
    l_lines.append("")
    l_lines.append(f"- generated_at: `{a_payload['generated_at']}`")
    l_lines.append(f"- analyzer: `{a_payload['analyzer']}`")
    l_lines.append(f"- test_files: `{a_payload['test_files']}`")
    l_lines.append(f"- public_symbols_total: `{a_payload['public_symbols_total']}`")
    l_lines.append(f"- covered_symbols: `{a_payload['covered_symbols']}`")
    l_lines.append(f"- missing_symbols: `{a_payload['missing_symbols']}`")
    l_lines.append(
        f"- thin_symbols_lt_{a_payload['min_refs']}: `{a_payload['thin_symbols']}`"
    )
    l_lines.append(f"- strict_thin: `{a_payload['strict_thin']}`")
    l_lines.append("")
    l_lines.append("## Missing Symbols")
    if not a_payload["missing_items"]:
        l_lines.append("- none")
    else:
        for l_item in a_payload["missing_items"]:
            l_lines.append(f"- `{l_item['name']}` ({l_item['source']})")
    l_lines.append("")
    l_lines.append(f"## Thin Symbols (< {a_payload['min_refs']} refs, Top 80)")
    if not a_payload["thin_items"]:
        l_lines.append("- none")
    else:
        for l_item in a_payload["thin_items"][:80]:
            l_files = ", ".join(l_item["test_files"][:6])
            l_lines.append(
                f"- `{l_item['name']}` refs={l_item['ref_count']} files={l_item['file_hits']} "
                f"[{l_files}]"
            )
    l_lines.append("")
    return "\n".join(l_lines)


def main() -> int:
    l_args = parse_args()
    if l_args.min_refs < 1:
        print("[PUBLIC-API-COVERAGE] invalid --min-refs (must be >= 1)")
        return 2

    l_repo_root = Path(__file__).resolve().parents[2]
    l_interface_files = [
        l_repo_root / "src" / "nextpas.core.simd.pas",
        l_repo_root / "src" / "nextpas.core.simd.api.pas",
        l_repo_root / "src" / "nextpas.core.simd.api.v2.pas",
    ]
    l_test_files = collect_test_files(l_repo_root)

    l_symbols = [
        l_item
        for l_path in l_interface_files
        for l_item in extract_symbols(l_repo_root, l_path)
    ]
    l_symbol_names = {normalize_symbol_name(l_name) for _, _, l_name in l_symbols}
    l_counts = {l_name: 0 for l_name in l_symbol_names}
    l_file_hits: dict[str, list[str]] = {l_name: [] for l_name in l_symbol_names}

    for l_test_path in l_test_files:
        l_text = strip_pascal_non_code(l_test_path.read_text(encoding="utf-8", errors="ignore"))
        l_tokens = TOKEN_RE.findall(l_text)
        if not l_tokens:
            continue
        l_counts_in_file: dict[str, int] = {}
        for l_token in l_tokens:
            l_token_name = normalize_symbol_name(l_token)
            if l_token_name in l_symbol_names:
                l_counts_in_file[l_token_name] = l_counts_in_file.get(l_token_name, 0) + 1
        if not l_counts_in_file:
            continue
        l_rel_file = str(l_test_path.relative_to(l_repo_root)).replace("\\", "/")
        for l_name, l_count in l_counts_in_file.items():
            l_counts[l_name] += l_count
            l_file_hits[l_name].append(l_rel_file)

    l_items = [
        SymbolCoverage(
            source=l_source,
            kind=l_kind,
            name=l_name,
            ref_count=l_counts.get(normalize_symbol_name(l_name), 0),
            file_hits=len(l_file_hits.get(normalize_symbol_name(l_name), [])),
            test_files=l_file_hits.get(normalize_symbol_name(l_name), []),
        )
        for l_source, l_kind, l_name in l_symbols
    ]
    l_missing_items = [asdict(l_item) for l_item in l_items if l_item.ref_count == 0]
    l_thin_items = [
        asdict(l_item)
        for l_item in sorted(l_items, key=lambda a_item: (a_item.ref_count, a_item.name))
        if 0 < l_item.ref_count < l_args.min_refs
    ]
    l_covered = sum(1 for l_item in l_items if l_item.ref_count > 0)
    l_ok = (len(l_missing_items) == 0) and (not l_args.strict_thin or len(l_thin_items) == 0)

    l_payload = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "analyzer": "pascal-state-machine-mask + case-insensitive token scan",
        "test_files": len(l_test_files),
        "public_symbols_total": len(l_items),
        "covered_symbols": l_covered,
        "missing_symbols": len(l_missing_items),
        "thin_symbols": len(l_thin_items),
        "min_refs": l_args.min_refs,
        "strict_thin": bool(l_args.strict_thin),
        "status": "ok" if l_ok else "fail",
        "missing_items": l_missing_items,
        "thin_items": l_thin_items,
        "items": [asdict(l_item) for l_item in l_items],
    }

    if l_args.json_file:
        Path(l_args.json_file).write_text(
            json.dumps(l_payload, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    if l_args.md_file:
        Path(l_args.md_file).write_text(render_markdown(l_payload), encoding="utf-8")

    if l_args.json:
        print(json.dumps(l_payload, ensure_ascii=False, indent=2))
    else:
        print("[PUBLIC-API-COVERAGE] simd public facade/api test coverage")
        print(f"  - test_files:           {l_payload['test_files']}")
        print(f"  - public_symbols_total: {l_payload['public_symbols_total']}")
        print(f"  - covered_symbols:      {l_payload['covered_symbols']}")
        print(f"  - missing_symbols:      {l_payload['missing_symbols']}")
        print(f"  - thin_symbols(<{l_args.min_refs}): {l_payload['thin_symbols']}")
        print(f"  - analyzer: {l_payload['analyzer']}")
        if l_missing_items:
            print("  - missing preview:")
            for l_item in l_missing_items[:20]:
                print(f"    * {l_item['name']} ({l_item['source']})")
        if l_thin_items:
            print("  - thin preview:")
            for l_item in l_thin_items[:20]:
                print(
                    f"    * {l_item['name']}: refs={l_item['ref_count']} files={l_item['file_hits']}"
                )
        if l_ok:
            print("[PUBLIC-API-COVERAGE] OK")
        elif l_missing_items:
            print("[PUBLIC-API-COVERAGE] FAIL (missing public API test refs)")
        else:
            print("[PUBLIC-API-COVERAGE] FAIL (strict thin threshold breached)")

    if l_args.summary_line:
        print(
            "PUBLIC_API_TEST_COVERAGE_SUMMARY "
            f"test_files={l_payload['test_files']} "
            f"symbols={l_payload['public_symbols_total']} "
            f"covered={l_payload['covered_symbols']} "
            f"missing={l_payload['missing_symbols']} "
            f"thin={l_payload['thin_symbols']} "
            f"min_refs={l_args.min_refs} "
            f"strict_thin={int(l_args.strict_thin)} "
            f"status={l_payload['status']}"
        )

    if l_missing_items:
        return 1
    if l_args.strict_thin and l_thin_items:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

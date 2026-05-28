#!/usr/bin/env python3
"""Generate SIMD public-interface checklist v2 with test-reference clues."""

from __future__ import annotations

import argparse
import collections
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any


DECL_RE = re.compile(
    r"^\s*(?P<kind>function|procedure)\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)\b",
    re.IGNORECASE | re.MULTILINE,
)
IDENT_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
INCLUDE_RE = re.compile(r"\{\$I\s+([^}]+)\}", re.IGNORECASE)


@dataclass
class SymbolDecl:
    source: str
    kind: str
    name: str
    exact_refs: int
    normalized_refs: int
    test_refs: int


@dataclass
class ImplementationCoverage:
    total_slots: int
    backend_slots: dict[str, int]
    scalar_only_slots: list[str]


def extract_interface_text(a_file: Path) -> str:
    l_text = a_file.read_text(encoding="utf-8", errors="ignore")
    l_parts = re.split(r"^\s*implementation\b.*$", l_text, maxsplit=1, flags=re.IGNORECASE | re.MULTILINE)
    return l_parts[0]


def normalize_symbol(a_symbol: str) -> str:
    return re.sub(r"_+", "", a_symbol).lower()


def read_text_with_local_includes(a_file: Path, a_seen: set[Path] | None = None) -> str:
    if a_seen is None:
        a_seen = set()

    l_file = a_file.resolve()
    if l_file in a_seen:
        return ""
    a_seen.add(l_file)

    l_text = l_file.read_text(encoding="utf-8", errors="ignore")

    def repl(a_match: re.Match[str]) -> str:
        l_include_name = a_match.group(1).strip().strip("'\"")
        l_include_path = (l_file.parent / l_include_name).resolve()
        if not l_include_path.exists():
            return a_match.group(0)
        return read_text_with_local_includes(l_include_path, a_seen)

    return INCLUDE_RE.sub(repl, l_text)


def build_test_counters(a_tests_text: str) -> tuple[collections.Counter[str], collections.Counter[str]]:
    l_exact: collections.Counter[str] = collections.Counter()
    l_normalized: collections.Counter[str] = collections.Counter()
    for l_token in IDENT_RE.findall(a_tests_text):
        l_exact[l_token] += 1
        l_normalized[normalize_symbol(l_token)] += 1
    return l_exact, l_normalized


def extract_symbols(
    a_repo_root: Path,
    a_file: Path,
    a_exact_counter: collections.Counter[str],
    a_normalized_counter: collections.Counter[str],
) -> list[SymbolDecl]:
    l_interface = extract_interface_text(a_file)
    l_symbols: list[SymbolDecl] = []
    for l_match in DECL_RE.finditer(l_interface):
        l_kind = l_match.group("kind").lower()
        l_name = l_match.group("name")
        l_exact_refs = a_exact_counter[l_name]
        l_normalized_refs = a_normalized_counter[normalize_symbol(l_name)]
        l_refs = max(l_exact_refs, l_normalized_refs)
        l_symbols.append(
            SymbolDecl(
                source=str(a_file.relative_to(a_repo_root)).replace("\\", "/"),
                kind=l_kind,
                name=l_name,
                exact_refs=l_exact_refs,
                normalized_refs=l_normalized_refs,
                test_refs=l_refs,
            )
        )
    return l_symbols


def load_tests_text(a_repo_root: Path) -> str:
    l_parts: list[str] = []
    l_tests_root = a_repo_root / "tests"
    l_test_dirs = sorted(
        l_path for l_path in l_tests_root.glob("nextpas.core.simd*") if l_path.is_dir()
    )
    for l_dir in l_test_dirs:
        for l_file in sorted(l_dir.rglob("*.pas")):
            l_parts.append(l_file.read_text(encoding="utf-8", errors="ignore"))
    return "\n".join(l_parts)


def extract_dispatch_slots(a_dispatch_file: Path) -> set[str]:
    l_text = read_text_with_local_includes(a_dispatch_file).splitlines()
    l_slots: set[str] = set()
    l_in_record = False
    for l_line in l_text:
        if not l_in_record:
            if re.search(r"\bTSimdDispatchTable\s*=\s*record\b", l_line):
                l_in_record = True
            continue
        if re.match(r"\s*end;\s*$", l_line):
            break
        l_match = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(?:function|procedure)\b", l_line)
        if l_match:
            l_slots.add(l_match.group(1))
    return l_slots


def extract_assigned_slots(a_file: Path, a_slot_set: set[str]) -> set[str]:
    l_text = read_text_with_local_includes(a_file)
    l_assigned = set(re.findall(r"\b(?:dispatchTable|table)\.([A-Za-z_][A-Za-z0-9_]*)\s*:=", l_text))
    return l_assigned & a_slot_set


def build_implementation_coverage(a_repo_root: Path) -> ImplementationCoverage:
    l_dispatch_file = a_repo_root / "src" / "nextpas.core.simd.dispatch.pas"
    l_slot_set = extract_dispatch_slots(l_dispatch_file)

    l_backend_files = {
        "scalar": l_dispatch_file,
        "sse2": a_repo_root / "src" / "nextpas.core.simd.sse2.pas",
        "sse3": a_repo_root / "src" / "nextpas.core.simd.sse3.pas",
        "ssse3": a_repo_root / "src" / "nextpas.core.simd.ssse3.pas",
        "sse41": a_repo_root / "src" / "nextpas.core.simd.sse41.pas",
        "sse42": a_repo_root / "src" / "nextpas.core.simd.sse42.pas",
        "avx2": a_repo_root / "src" / "nextpas.core.simd.avx2.pas",
        "avx512": a_repo_root / "src" / "nextpas.core.simd.avx512.pas",
        "neon": a_repo_root / "src" / "nextpas.core.simd.neon.pas",
        "riscvv": a_repo_root / "src" / "nextpas.core.simd.riscvv.pas",
    }

    l_backend_slots: dict[str, int] = {}
    l_non_scalar_union: set[str] = set()
    for l_name, l_file in l_backend_files.items():
        l_counted = extract_assigned_slots(l_file, l_slot_set)
        l_backend_slots[l_name] = len(l_counted)
        if l_name != "scalar":
            l_non_scalar_union |= l_counted

    l_scalar_only_slots = sorted(l_slot_set - l_non_scalar_union)
    return ImplementationCoverage(
        total_slots=len(l_slot_set),
        backend_slots=l_backend_slots,
        scalar_only_slots=l_scalar_only_slots,
    )


def render_markdown(
    a_symbols: list[SymbolDecl],
    a_old_baseline: int,
    a_impl_cov: ImplementationCoverage,
    a_completeness_snapshot: dict[str, Any] | None,
) -> str:
    l_total = len(a_symbols)
    l_covered = sum(1 for l_item in a_symbols if l_item.test_refs > 0)
    l_backlog = l_total - l_covered
    l_delta = l_total - a_old_baseline

    l_by_source: dict[str, list[SymbolDecl]] = {}
    for l_item in a_symbols:
        l_by_source.setdefault(l_item.source, []).append(l_item)

    l_lines: list[str] = []
    l_lines.append("# SIMD Interface Target Checklist v2 (2026-02-17)")
    l_lines.append("")
    l_lines.append("> Status: historical baseline.")
    l_lines.append(">")
    l_lines.append("> This document is kept for drift comparison, template reuse, or local design history.")
    l_lines.append("> It is not part of the active whole-module execution chain.")
    l_lines.append("> Before starting from any SIMD plan, check `docs/plans/2026-05-10-simd-plan-status-index.md`.")
    l_lines.append("")
    l_lines.append("## Baseline")
    l_lines.append(f"- Previous baseline (2026-02-09): `{a_old_baseline}`")
    l_lines.append(f"- Current baseline: `{l_total}`")
    l_lines.append(f"- Drift: `{l_delta:+d}`")
    l_lines.append(f"- Test-reference clue `[x]`: `{l_covered}`")
    l_lines.append(f"- Backlog clue `[ ]`: `{l_backlog}`")
    l_lines.append("")
    l_lines.append("## Implementation Coverage Snapshot")
    l_lines.append(f"- Dispatch slots total: `{a_impl_cov.total_slots}`")
    for l_backend in ["scalar", "sse2", "sse3", "ssse3", "sse41", "sse42", "avx2", "avx512", "neon", "riscvv"]:
        l_bound = a_impl_cov.backend_slots.get(l_backend, 0)
        l_ratio = (l_bound / a_impl_cov.total_slots) if a_impl_cov.total_slots else 0.0
        l_lines.append(f"- {l_backend}: `{l_bound}/{a_impl_cov.total_slots}` ({l_ratio:.1%})")
    l_lines.append(f"- Scalar-only slots (no non-scalar backend binding): `{len(a_impl_cov.scalar_only_slots)}`")
    l_lines.append("")
    l_lines.append("## Method")
    l_lines.append("- Source of truth: interface declarations in `src/nextpas.core.simd.pas` and `src/nextpas.core.simd.api.pas`.")
    l_lines.append("- Coverage clue: token presence in `tests/nextpas.core.simd/**/*.pas` (heuristic, not proof of semantic coverage).")
    l_lines.append("- Matching rule: `max(exact token refs, normalized refs)` where normalized means lower-case + remove underscores.")
    l_lines.append("- Backlog rule: declarations with zero test-token references are marked `[ ]`.")
    l_lines.append("")
    l_lines.append("## Machine Check Snapshot")
    if a_completeness_snapshot is None:
        l_lines.append("- completeness snapshot: not found (run `check_interface_implementation_completeness.py` first)")
    else:
        l_severity = a_completeness_snapshot.get("severity_counts", {})
        l_lines.append(f"- generated_at: `{a_completeness_snapshot.get('generated_at', '-')}`")
        l_lines.append(f"- dispatch_slots_total: `{a_completeness_snapshot.get('dispatch_slots_total', '-')}`")
        l_lines.append(
            f"- severity: `P0={l_severity.get('P0', 0)} / P1={l_severity.get('P1', 0)} / P2={l_severity.get('P2', 0)}`"
        )
    l_lines.append("")
    l_lines.append("## Backlog Symbols ([ ] no test-token reference)")
    for l_item in a_symbols:
        if l_item.test_refs == 0:
            l_lines.append(f"- `{l_item.name}` ({l_item.source})")
    l_lines.append("")
    l_lines.append("## Detailed Checklist")
    for l_source in sorted(l_by_source.keys()):
        l_group = l_by_source[l_source]
        l_lines.append("")
        l_lines.append(f"### `{l_source}` ({len(l_group)})")
        l_lines.append("| Status | Symbol | Kind | ExactRef | NormalizedRef | TestRefCount |")
        l_lines.append("|---|---|---|---|---|---|")
        for l_item in l_group:
            l_status = "[x]" if l_item.test_refs > 0 else "[ ]"
            l_lines.append(
                f"| {l_status} | `{l_item.name}` | `{l_item.kind}` | "
                f"{l_item.exact_refs} | {l_item.normalized_refs} | {l_item.test_refs} |"
            )
    l_lines.append("")
    l_lines.append("## Scalar-only Slot Sample")
    for l_name in a_impl_cov.scalar_only_slots[:80]:
        l_lines.append(f"- `{l_name}`")
    l_lines.append("")
    return "\n".join(l_lines)


def main() -> int:
    l_parser = argparse.ArgumentParser(description="Generate SIMD interface checklist v2")
    l_parser.add_argument(
        "--output",
        default="docs/plans/2026-02-17-simd-interface-target-checklist-v2.md",
        help="Output markdown path (repo-relative)",
    )
    l_parser.add_argument("--old-baseline", type=int, default=439, help="Previous documented baseline count")
    l_parser.add_argument(
        "--completeness-json",
        default="tests/nextpas.core.simd/logs/interface_completeness.json",
        help="Machine-check snapshot json path (repo-relative)",
    )
    l_args = l_parser.parse_args()

    l_repo_root = Path(__file__).resolve().parents[2]
    l_sources = [
        l_repo_root / "src" / "nextpas.core.simd.pas",
        l_repo_root / "src" / "nextpas.core.simd.api.pas",
    ]

    l_tests_text = load_tests_text(l_repo_root)
    l_exact_counter, l_normalized_counter = build_test_counters(l_tests_text)
    l_symbols: list[SymbolDecl] = []
    for l_source in l_sources:
        l_symbols.extend(extract_symbols(l_repo_root, l_source, l_exact_counter, l_normalized_counter))
    l_impl_cov = build_implementation_coverage(l_repo_root)

    l_completeness_json = l_repo_root / l_args.completeness_json
    l_completeness_snapshot: dict[str, Any] | None = None
    if l_completeness_json.exists():
        l_completeness_snapshot = json.loads(l_completeness_json.read_text(encoding="utf-8"))

    l_output = l_repo_root / l_args.output
    l_output.parent.mkdir(parents=True, exist_ok=True)
    l_output.write_text(
        render_markdown(l_symbols, l_args.old_baseline, l_impl_cov, l_completeness_snapshot),
        encoding="utf-8",
    )

    print(f"[CHECKLIST] output={l_output}")
    print(
        f"[CHECKLIST] total={len(l_symbols)} old={l_args.old_baseline} "
        f"delta={len(l_symbols) - l_args.old_baseline:+d} "
        f"covered={sum(1 for x in l_symbols if x.test_refs > 0)} backlog={sum(1 for x in l_symbols if x.test_refs == 0)}"
    )
    print(
        f"[CHECKLIST] dispatch_slots={l_impl_cov.total_slots} "
        f"scalar={l_impl_cov.backend_slots.get('scalar', 0)} "
        f"sse2={l_impl_cov.backend_slots.get('sse2', 0)} "
        f"sse3={l_impl_cov.backend_slots.get('sse3', 0)} "
        f"ssse3={l_impl_cov.backend_slots.get('ssse3', 0)} "
        f"sse41={l_impl_cov.backend_slots.get('sse41', 0)} "
        f"sse42={l_impl_cov.backend_slots.get('sse42', 0)} "
        f"avx2={l_impl_cov.backend_slots.get('avx2', 0)} "
        f"avx512={l_impl_cov.backend_slots.get('avx512', 0)} "
        f"neon={l_impl_cov.backend_slots.get('neon', 0)} "
        f"riscvv={l_impl_cov.backend_slots.get('riscvv', 0)} "
        f"scalar_only={len(l_impl_cov.scalar_only_slots)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
